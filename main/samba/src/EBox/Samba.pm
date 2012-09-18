# Copyright (C) 2012 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package EBox::Samba;

use strict;
use warnings;

use base qw( EBox::Module::Service
             EBox::FirewallObserver
             EBox::LdapModule
             EBox::LogObserver );

use EBox::Global;
use EBox::Service;
use EBox::Sudo;
use EBox::SambaLdapUser;
use EBox::Network;
use EBox::SambaFirewall;
use EBox::SambaLogHelper;
use EBox::Menu::Item;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Config;
use EBox::DBEngineFactory;
use EBox::LDB;
use EBox::Util::Random qw( generate );
use EBox::UsersAndGroups;
use EBox::Samba::Model::SambaShares;

use Perl6::Junction qw( any );
use Error qw(:try);
use File::Slurp;
use File::Temp;

use constant SAMBA_DIR            => '/home/samba/';
use constant SAMBA_PROVISION_FILE => SAMBA_DIR . '.provisioned';
use constant SAMBATOOL            => '/usr/bin/samba-tool';
use constant SAMBAPROVISION       => '/usr/share/samba/setup/provision';
use constant SAMBACONFFILE        => '/etc/samba/smb.conf';
use constant PRIVATE_DIR          => '/var/lib/samba/private/';
use constant SAMBA_DNS_ZONE       => PRIVATE_DIR . 'named.conf';
use constant SAMBA_DNS_POLICY     => PRIVATE_DIR . 'named.conf.update';
use constant SAMBA_DNS_KEYTAB     => PRIVATE_DIR . 'dns.keytab';
use constant SAM_DB               => PRIVATE_DIR . 'sam.ldb';
use constant SAMBA_PRIVILEGED_SOCKET => PRIVATE_DIR . '/ldap_priv';
use constant FSTAB_FILE           => '/etc/fstab';
use constant SYSVOL_DIR           => '/var/lib/samba/sysvol';
use constant SHARES_DIR           => SAMBA_DIR . '/shares';
use constant PROFILES_DIR         => SAMBA_DIR . '/profiles';
use constant LOGON_SCRIPT         => 'logon.bat';
use constant LOGON_DEFAULT_SCRIPT => 'zentyal-logon.bat';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(
        name => 'samba',
        printableName => __('File Sharing'),
        @_);
    bless ($self, $class);
    return $self;
}

# Method: bootDepends
#
#   Samba depends on CUPS only if printers module enabled.
#
# Overrides:
#
#   <EBox::Module::Base::depends>
#
sub bootDepends
{
    my ($self) = @_;

    my $dependsList = $self->depends();

    my $module = 'printers';
    if (EBox::Global->modExists($module)) {
        my $printers = EBox::Global->modInstance($module);
        if ($printers->isEnabled()) {
            push (@{$dependsList}, $module);
        }
    }

    return $dependsList;
}

# Method: actions
#
#   Override EBox::Module::Service::actions
#
sub actions
{
    return [
        {
            'action' => __('Create Samba home directory for shares and groups'),
            'reason' => __('Zentyal will create the directories for Samba ' .
                           'shares and groups under /home/samba.'),
            'module' => 'samba',
        },
    ];
}

# Method: usedFiles
#
#   Override EBox::Module::Service::files
#
sub usedFiles
{
    return [
        {
            'file'   => SAMBACONFFILE,
            'reason' => __('To set up Samba according to your configuration.'),
            'module' => 'samba',
        },
        {
            'file'   => FSTAB_FILE,
            'reason' => __('To enable extended attributes and acls.'),
            'module' => 'samba',
        },
        {
            'file'   => '/etc/services',
            'reason' => __('To add microsoft specific services'),
            'module' => 'samba',
        },
    ];
}

# Method: initialSetup
#
# Overrides:
#
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    # Create default rules and services only if enabling the first time
    unless ($version) {
        my $services = EBox::Global->modInstance('services');

        my $serviceName = 'samba';
        unless($services->serviceExists(name => $serviceName)) {
            $services->addMultipleService(
                'name' => $serviceName,
                'printableName' => 'Samba',
                'description' => __('File sharing (Samba) protocol'),
                'internal' => 1,
                'readOnly' => 1,
                'services' => $self->_services(),
            );
        }

        my $firewall = EBox::Global->modInstance('firewall');
        $firewall->setInternalService($serviceName, 'accept');
        $firewall->saveConfigRecursive();
    }
}

sub enableService
{
    my ($self, $status) = @_;

    if ($status) {
        my $throwException = 1;
        if ($self->{restoringBackup}) {
            $throwException = 0;
        }
        $self->_checkEnvironment($throwException);
    }

    if ($self->isEnabled() and not $status) {
        $self->setupDNS(0);
    } elsif (not $self->isEnabled() and $status and $self->isProvisioned()) {
        $self->setupDNS(1);
    }

    $self->SUPER::enableService($status);
}

# Method: _startService
#
#   Overrided to ensure proper permissions of the ldap_priv folder, where the
#   privileged socket that zentyal uses to connect is. This is a special socket
#   that samba create that allow r/w restricted attributes.
#   Samba expects the ldap_priv folder to be owned by root and mode 0750, or the
#   LDAP service won't run.
#
#   Here we set the expected permissions before start the daemon.
#
sub _startService
{
    my ($self) = @_;

    my $group = EBox::Config::group();
    EBox::Sudo::root("mkdir -p " . SAMBA_PRIVILEGED_SOCKET);
    EBox::Sudo::root("chgrp $group " . SAMBA_PRIVILEGED_SOCKET);
    EBox::Sudo::root("chmod 0750 " . SAMBA_PRIVILEGED_SOCKET);

    $self->SUPER::_startService(@_);
}

# Method: _enforceServiceState
#
#   Start the samba daemon is expensive and takes a while. After writing
#   smb.conf the daemon is started to make queries to LDB, so it is not
#   necessary to restart it after that. This method is overrided to avoid
#   this situation and restart samba twice while saving changes.
#
sub _enforceServiceState
{
    my ($self) = @_;

    if ($self->isEnabled() and $self->isProvisioned()) {
        $self->_startService();
    } else {
        $self->_stopService();
    }
}

sub _services
{
    my ($self) = @_;

    return [
            { # kerberos
                'protocol' => 'tcp/udp',
                'sourcePort' => 'any',
                'destinationPort' => '88',
                'description' => 'Kerberos authentication',
            },
            { # DCE endpoint resolution
                'protocol' => 'tcp',
                'sourcePort' => 'any',
                'destinationPort' => '135',
                'description' => 'DCE endpoint resolution',
            },
            { # netbios-ns
                'protocol' => 'udp',
                'sourcePort' => 'any',
                'destinationPort' => '137',
                'description' => 'NETBIOS name service',
            },
            { # netbios-dgm
                'protocol' => 'udp',
                'sourcePort' => 'any',
                'destinationPort' => '138',
                'description' => 'NETBIOS datagram service',
            },
            { # netbios-ssn
                'protocol' => 'tcp',
                'sourcePort' => 'any',
                'destinationPort' => '139',
                'description' => 'NETBIOS session service',
            },
            { # samba LDAP
                'protocol' => 'tcp/udp',
                'sourcePort' => 'any',
                'destinationPort' => '389',
                'description' => 'Lightweight Directory Access Protocol',
            },
            { # microsoft-ds
                'protocol' => 'tcp',
                'sourcePort' => 'any',
                'destinationPort' => '445',
                'description' => 'Microsoft directory services',
            },
            { # kerberos change/set password
                'protocol' => 'tcp/udp',
                'sourcePort' => 'any',
                'destinationPort' => '464',
                'description' => 'Kerberos set/change password',
            },
            { # LDAP over TLS/SSL
                'protocol' => 'tcp',
                'sourcePort' => 'any',
                'destinationPort' => '636',
                'description' => 'LDAP over TLS/SSL',
            },
            { # unknown???
                'protocol' => 'tcp',
                'sourcePort' => 'any',
                'destinationPort' => '1024',
            },
            { # msft-gc
                'protocol' => 'tcp',
                'sourcePort' => 'any',
                'destinationPort' => '3268',
                'description' => 'Microsoft global catalog',
            },
            { # msft-gc-ssl
                'protocol' => 'tcp',
                'sourcePort' => 'any',
                'destinationPort' => '3269',
                'description' => 'Microsoft global catalog over SSL',
            },
        ];
}

# Method: enableActions
#
#   Override EBox::Module::Service::enableActions
#
sub enableActions
{
    my ($self) = @_;

    # Remount filesystem with user_xattr and acl options
    EBox::debug('Setting up filesystem options');
    EBox::Sudo::root(EBox::Config::scripts('samba') . 'setup-filesystem');

    my $group = EBox::UsersAndGroups::DEFAULTGROUP();
    my $nobody = EBox::Samba::Model::SambaShares::GUEST_DEFAULT_USER();
    my @cmds = ();
    push (@cmds, 'mkdir -p ' . SAMBA_DIR);
    push (@cmds, "chown root:$group " . SAMBA_DIR);
    push (@cmds, "chmod 770 " . SAMBA_DIR);
    push (@cmds, "setfacl -m u:$nobody:rx " . SAMBA_DIR);
    push (@cmds, 'mkdir -p ' . PROFILES_DIR);
    push (@cmds, "chown root:$group " . PROFILES_DIR);
    push (@cmds, "chmod 770 " . PROFILES_DIR);
    push (@cmds, 'mkdir -p ' . SHARES_DIR);
    push (@cmds, "chown root:$group " . SHARES_DIR);
    push (@cmds, "chmod 770 " . SHARES_DIR);
    push (@cmds, "setfacl -m u:$nobody:rx " . SHARES_DIR);
    EBox::debug('Creating directories');
    EBox::Sudo::root(@cmds);
}

sub isProvisioned
{
    my ($self) = @_;

    return EBox::Sudo::fileTest('-f', SAMBA_PROVISION_FILE);
}

sub setProvisioned
{
    my ($self, $provisioned) = @_;

    if ($provisioned) {
        EBox::Sudo::root("touch " . SAMBA_PROVISION_FILE);
    } else {
        EBox::Sudo::root("rm -f " . SAMBA_PROVISION_FILE);
    }
}

# Method: shares
#
#   It returns the custom shares
#
# Parameters:
#
#     all - return all shares regardless of their permission
#           level. Otherwise shares without permssions or guset access are
#           ignored. Default: false
#
# Returns:
#
#   Array ref containing hash ref with:
#
#   share   - share's name
#   path    - share's path
#   comment - share's comment
#   readOnly  - string containing users and groups with read-only permissions
#   readWrite - string containing users and groups with read and write
#               permissions
#   administrators  - string containing users and groups with admin priviliges
#                     on the share
#   validUsers - readOnly + readWrite + administrators
#
sub shares
{
    my ($self, $all) = @_;

    my $shares = $self->model('SambaShares');
    my @shares = ();

    for my $id (@{$shares->enabledRows()}) {
        my $row = $shares->row($id);
        my @readOnly;
        my @readWrite;
        my @administrators;
        my $shareConf = {};

        my $path = $row->elementByName('path');
        if ($path->selectedType() eq 'zentyal') {
            $shareConf->{'path'} = SHARES_DIR . '/' . $path->value();
        } else {
            $shareConf->{'path'} = $path->value();
        }
        $shareConf->{'share'} = $row->valueByName('share');
        $shareConf->{'comment'} = $row->valueByName('comment');
        $shareConf->{'guest'} = $row->valueByName('guest');
        $shareConf->{'groupShare'} = $row->valueByName('groupShare');

        for my $subId (@{$row->subModel('access')->ids()}) {
            my $subRow = $row->subModel('access')->row($subId);
            my $userType = $subRow->elementByName('user_group');
            my $preCar = '';
            if ($userType->selectedType() eq 'group') {
                $preCar = '@';
            }
            my $user =  $preCar . '"' . $userType->printableValue() . '"';

            my $permissions = $subRow->elementByName('permissions');

            if ($permissions->value() eq 'readOnly') {
                push (@readOnly, $user);
            } elsif ($permissions->value() eq 'readWrite') {
                push (@readWrite, $user);
            } elsif ($permissions->value() eq 'administrator') {
                push (@administrators, $user)
            }
        }

        if (not $all) {
            next unless (@readOnly or @readWrite or @administrators
                         or $shareConf->{'guest'});
        }

        $shareConf->{'readOnly'} = join (', ', @readOnly);
        $shareConf->{'readWrite'} = join (', ', @readWrite);
        $shareConf->{'administrators'} = join (', ', @administrators);
        $shareConf->{'validUsers'} = join (', ', @readOnly,
                                                 @readWrite,
                                                 @administrators);

        push (@shares, $shareConf);
    }

    return \@shares;
}

sub defaultAntivirusSettings
{
    my ($self) = @_;

    my $antivirus = $self->model('AntivirusDefault');
    return $antivirus->value('scan');
}

sub antivirusExceptions
{
    my ($self) = @_;

    my $model = $self->model('AntivirusExceptions');
    my $exceptions = {
        'share' => {},
        'group' => {},
    };

    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $element = $row->elementByName('user_group_share');
        my $type = $element->selectedType();
        if ($type eq 'users') {
            $exceptions->{'users'} = 1;
        } else {
            my $value = $element->printableValue();
            $exceptions->{$type}->{$value} = 1;
        }
    }

    return $exceptions;
}

sub antivirusConfig
{
    my ($self) = @_;

    my $conf = {};
    my @keys = ('verbose_file_logging', 'scan_on_open', 'scan_on_close', 'deny_access_on_error',
                'send_warning_message', 'infected_file_action', 'quarantine_prefix',
                'quarantine_dir', 'max_lrufiles',
                'lrufiles_invalidate_time', 'exclude_file_types', 'exclude_file_regexp',
                'delete_file_on_quarantine_failure', 'max_file_size', 'max_scan_size',
                'max_files', 'max_recursion_level');

    foreach my $key (@keys) {
        my $value = EBox::Config::configkey($key);
        if ($value) {
            $conf->{$key} = $value;
        }
    }

    return $conf;
}

sub defaultRecycleSettings
{
    my ($self) = @_;

    my $recycle = $self->model('RecycleDefault');
    return $recycle->row()->valueByName('enabled');
}

sub recycleExceptions
{
    my ($self) = @_;

    my $model = $self->model('RecycleExceptions');
    my $exceptions = {
        'share' => {},
        'group' => {},
    };

    for my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $element = $row->elementByName('user_group_share');
        my $type = $element->selectedType();
        if ($type eq 'users') {
            $exceptions->{'users'} = 1;
        } else {
            my $value = $element->printableValue();
            $exceptions->{$type}->{$value} = 1;
        }
    }
    return $exceptions;
}

sub recycleConfig
{
    my ($self) = @_;

    my $conf = {};
    my @keys = ('repository', 'directory_mode', 'keeptree', 'versions', 'touch', 'minsize',
                'maxsize', 'exclude', 'excludedir', 'noversions');

    foreach my $key (@keys) {
        my $value = EBox::Config::configkey($key);
        if ($value) {
            $conf->{$key} = $value;
        }
    }

    return $conf;
}

# Method: _checkEnvironment
#
#   This method ensure that the environment is properly configured for
#   samba provision.
#
# Arguments:
#
#   throwException - 0 print warn on log, 1 throw exception
#
# Returns:
#
#   The IP address to use for provision
#
sub _checkEnvironment
{
    my ($self, $throwException) = @_;

    unless (defined $throwException) {
        throw EBox::Exceptions::MissingArgument('throwException');
    }

    # Get the own doamin
    my $sysinfo    = EBox::Global->modInstance('sysinfo');
    my $hostDomain = $sysinfo->hostDomain();
    my $hostName   = $sysinfo->hostName();

    # Get the kerberos realm
    my $users = EBox::Global->modInstance('users');
    my $realm = $users->kerberosRealm();

    # The own doamin and the kerberos realm must be equal
    unless (lc $hostDomain eq lc $realm) {
        $self->enableService(0);
        my $err = __x("The host domain '{d}' has to be the same than the kerberos realm '{r}'", d => $hostDomain, r => $realm);
        if ($throwException) {
            throw EBox::Exceptions::External($err);
        } else {
            EBox::warn($err);
        }
    }

    # Check the domain exists in DNS module
    my $dns = EBox::Global->modInstance('dns');
    my $domainModel = $dns->model('DomainTable');
    my $domainRow = $domainModel->find(domain => $hostDomain);
    unless (defined $domainRow) {
        $self->enableService(0);
        my $err = __x("The required domain '{d}' could not be found in the dns module", d => $hostDomain);
        if ($throwException) {
            throw EBox::Exceptions::External($err);
        } else {
            EBox::warn($err);
        }
    }

    # Check the hostname exists in the DNS module
    my $hostsModel = $domainRow->subModel('hostnames');
    my $hostRow = $hostsModel->find(hostname => $hostName);
    unless (defined $hostRow) {
        $self->enableService(0);
        my $err = __x("The required host record '{h}' could not be found in the domain '{d}'",
                      h => $hostName, d => $hostDomain);
        if ($throwException) {
            throw EBox::Exceptions::External($err);
        } else {
            EBox::warn($err);
        }
    }

    # Get the IP addresses models (domain and hostname)
    my $domainIPsModel = $domainRow->subModel('ipAddresses');
    my $hostIPsModel = $hostRow->subModel('ipAddresses');

    # Get the IP address to use for provision, and check that this IP is assigned
    # to the domain
    my $network = EBox::Global->modInstance('network');
    my $ifaces = $self->sambaInterfaces();
    my $provisionIP = undef;
    foreach my $iface (@{$ifaces}) {
        next if $iface eq 'lo';
        my $ifaceAddrs = $network->ifaceAddresses($iface);
        foreach my $data (@{$ifaceAddrs}) {
            # Got one candidate address, check that it is assigned to the DNS domain
            my $inDomainModel = 0;
            my $inHostModel = 0;
            foreach my $rowId (@{$domainIPsModel->ids()}) {
                my $row = $domainIPsModel->row($rowId);
                if ($row->valueByName('ip') eq $data->{address}) {
                    $inDomainModel = 1;
                    last;
                }
            }
            foreach my $rowId (@{$hostIPsModel->ids()}) {
                my $row = $hostIPsModel->row($rowId);
                if ($row->valueByName('ip') eq $data->{address}) {
                    $inHostModel = 1;
                    last;
                }
            }
            if ($inDomainModel and $inHostModel) {
                $provisionIP = $data->{address};
                last;
            }
        }
        last if defined $provisionIP;
    }
    unless (defined $provisionIP) {
        $self->enableService(0);
        my $err = __("Samba can't be provisioned if no IP addresses are set and the " .
                   "DNS domain is properly configured. Ensure that you have at least a " .
                   "IP address assigned to an internal interface, and this IP has to be " .
                   "assigned to the domain and to the hostname in the DNS domain.");
        if ($throwException) {
            throw EBox::Exceptions::External($err);
        } else {
            EBox::warn($err);
        }
    }

    return $provisionIP;
}

# Method: provision
#
#   This method provision the database
#
sub provision
{
    my ($self) = @_;

    # Stop the service
    $self->stopService();

    # Check environment
    my $provisionIP = $self->_checkEnvironment(2);

    # Delete samba config file and private folder
    EBox::Sudo::root('rm -f ' . SAMBACONFFILE);
    EBox::Sudo::root('rm -rf ' . PRIVATE_DIR . '/*');

    my $mode = $self->mode();
    my $fs = EBox::Config::configkey('samba_fs');
    if ($mode eq EBox::Samba::Model::GeneralSettings::MODE_DC()) {
        $self->provisionAsDC($fs, $provisionIP);
    } elsif ($mode eq EBox::Samba::Model::GeneralSettings::MODE_ADC()) {
        $self->provisionAsADC();
    } else {
        throw EBox::Exceptions::External(__x('The mode {mode} is not supported'), mode => $mode);
    }
}

sub provisionAsDC
{
    my ($self, $fs, $provisionIP) = @_;

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $usersModule = EBox::Global->modInstance('users');

    my $cmd = SAMBAPROVISION .
        " --domain='" . $self->workgroup() . "'" .
        " --workgroup='" . $self->workgroup() . "'" .
        " --realm='" . $usersModule->kerberosRealm() . "'" .
        " --dns-backend=BIND9_DLZ" .
        " --use-xattrs=yes " .
        " --use-rfc2307 " .
        " --server-role='" . $self->mode() . "'" .
        " --users='" . $usersModule->DEFAULTGROUP() . "'" .
        " --host-name='" . $sysinfo->hostName() . "'" .
        " --host-ip='" . $provisionIP . "'";
    $cmd .= ' --use-ntvfs' if (defined $fs and $fs eq 'ntvfs');

    EBox::debug("Provisioning database '$cmd'");
    $cmd .= " --adminpass='" . $self->administratorPassword() . "'";

    # Use silent root to avoid showing the admin pass in the logs if
    # provision command fails.
    my $output = EBox::Sudo::silentRoot($cmd);
    if ($? == 0) {
        EBox::debug("Provision result: @{$output}");
    } else {
        my @error = ();
        my $stderr = EBox::Config::tmp() . 'stderr';
        if (-r $stderr) {
            @error = read_file($stderr);
        }
        throw EBox::Exceptions::Internal("Error provisioning database. Output: @{$output}, error:@error");
    };

    # Disable password policy
    # NOTE complexity is disabled because when changing password in
    #      zentyal the command may fail if it do not meet requirements,
    #      ending with different passwords
    EBox::debug('Setting password policy');
    $cmd = SAMBATOOL . " domain passwordsettings set " .
                       " --complexity=off "  .
                       " --min-pwd-length=0" .
                       " --min-pwd-age=0" .
                       " --max-pwd-age=365";
    EBox::Sudo::root($cmd);

    # Write smb.conf to grant rw access to zentyal group on the
    # privileged socket
    $self->writeSambaConfig();

    # Set DNS. The domain should have been created by the users
    # module.
    $self->setupDNS(1);

    # Start managed service to let it create the LDAP socket
    $self->_startService();

    # Load all zentyal users and groups into ldb
    $self->ldb->ldapUsersToLdb();
    $self->ldb->ldapGroupsToLdb();
    $self->ldb->ldapServicePrincipalsToLdb();

    # TODO Echo the current TS to the .s4_ts

    # Map domain guest account to nobody user
    my $guestSID = $self->ldb->domainSID() . '-501';
    my $guestGroupSID = $self->ldb->domainSID() . '-514';
    #my $uid = getpwnam(EBox::Samba::Model::SambaShares::GUEST_DEFAULT_USER());
    #my $gid = getgrnam(EBox::Samba::Model::SambaShares::GUEST_DEFAULT_GROUP());
    # FIXME Why is this not working during first intall???
    my $uid = 65534;
    my $gid = 65534;
    my $typeUID = EBox::LDB::IdMapDb::TYPE_UID();
    my $typeGID = EBox::LDB::IdMapDb::TYPE_UID();
    EBox::info("Mapping guest account");
    $self->ldb->idmap->setupNameMapping($guestSID, $typeUID, $uid);
    $self->ldb->idmap->setupNameMapping($guestGroupSID, $typeGID, $gid);

    # Mark the module as provisioned
    EBox::debug('Setting provisioned flag');
    $self->setProvisioned(1);
}

sub provisionAsADC
{
    my ($self) = @_;

    my $model = $self->model('GeneralSettings');
    my $domainToJoin = $model->value('realm');
    my $dcFQDN = $model->value('dcfqdn');
    my $domainDNS = $model->value('dnsip');
    my $adminAccount = $model->value('adminAccount');
    my $adminAccountPwd = $model->value('password');
    my $netbiosDomain = $model->value('workgroup');

    # If the host domain or the users kerberos realm does not
    # match the domain we are trying to join warn the user and
    # abort
    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $usersModule = EBox::Global->modInstance('users');
    my $hostName = $sysinfo->hostName();
    my $ucHostName = uc ($hostName);
    my $krbRealm = $usersModule->kerberosRealm();
    my $fqdn = $sysinfo->fqdn();
    if (lc ($sysinfo->hostDomain()) ne lc ($domainToJoin) or
        lc ($sysinfo->hostDomain()  ne lc ($krbRealm))) {
        throw EBox::Exceptions::External(
            __('The server domain and kerberos realm must match the ' .
               'domain you are trying to join.'));
    }

    my $dnsFile = undef;
    try {
        EBox::info("Joining to domain '$domainToJoin' as DC");

        # Set the domain DNS as the primary resolver. This will also let to get
        # the kerberos ticket for the admin account.
        EBox::debug("Setting domain DNS server '$domainDNS' as the primary resolver");
        $dnsFile = new File::Temp(TEMPLATE => 'resolvXXXXXX',
                                  DIR      => EBox::Config::tmp());
        EBox::Sudo::root("cp /etc/resolv.conf $dnsFile");
        my $array = [];
        push (@{$array}, searchDomain => $domainToJoin);
        push (@{$array}, nameservers => [ $domainDNS ]);
        $self->writeConfFile(EBox::Network::RESOLV_FILE(),
                             'network/resolv.conf.mas',
                             $array);

        # Join the domain
        EBox::debug("Joining to the domain");
        my @cmds;
        push (@cmds, SAMBATOOL . " domain join $domainToJoin DC " .
            " -U $adminAccount " .
            " --workgroup='$netbiosDomain' " .
            " --password='$adminAccountPwd' " .
            " --server=$dcFQDN");
        my $output = EBox::Sudo::silentRoot(@cmds);
        if ($? == 0) {
            $self->setProvisioned(1);
            EBox::debug("Provision result: @{$output}");
        } else {
            my @error = ();
            my $stderr = EBox::Config::tmp() . 'stderr';
            if (-r $stderr) {
                @error = read_file($stderr);
            }
            throw EBox::Exceptions::Internal("Error joining to domain: @error");
        }

        $self->setupDNS(1);

        # Write smb.conf to grant rw access to zentyal group on the
        # privileged socket
        $self->writeSambaConfig();

        # Start managed service to let it create the LDAP socket
        EBox::debug('Starting service');
        $self->_startService();

        # Wait for RID allocation
        my $args = {
            base => "CN=$hostName,OU=Domain Controllers," . $self->ldb->dn,
            scope => 'base',
            filter => '(objectClass=*)',
            attrs => ['rIDSetReferences'],
        };
        for (my $retries=12; $retries>=0; $retries--) {
            EBox::debug ("Waiting for RID allocation, $retries");
            my $result = $self->ldb->search($args);
            if ($result->count() == 1) {
                my $entry = $result->entry(0);
                my @val = $entry->get_value('rIDSetReferences');
                last if @val;
            }
            sleep (5);
        }

        # Purge users and groups
        EBox::info("Purging the Zentyal LDAP to import Samba users");
        my $usersMod = EBox::Global->modInstance('users');
        my $users = $usersMod->users();
        my $groups = $usersMod->groups();
        foreach my $user (@{$users}) {
            $user->deleteObject();
        }
        foreach my $group (@{$groups}) {
            $group->deleteObject();
        }

        # Load samba users and groups into Zentyal ldap
        $self->ldb->ldbUsersToLdap();
        $self->ldb->ldbGroupsToLdap();

        # Load Zentyal service principals into samba
        $self->ldb->ldapServicePrincipalsToLdb();

        # FIXME This should not be necessary, it is a samba bug.
        @cmds = ();
        push (@cmds, "rm -f " . SAMBA_DNS_KEYTAB);
        push (@cmds, SAMBATOOL . " spn add DNS/$fqdn $ucHostName\$");
        push (@cmds, SAMBATOOL . " domain exportkeytab " . SAMBA_DNS_KEYTAB .
            " --principal=$ucHostName\$");
        push (@cmds, SAMBATOOL . " domain exportkeytab " . SAMBA_DNS_KEYTAB .
            " --principal=DNS/$fqdn");
        push (@cmds, "chgrp bind " . SAMBA_DNS_KEYTAB);
        push (@cmds, "chmod g+r " . SAMBA_DNS_KEYTAB);
        EBox::Sudo::root(@cmds);

        # Map domain guest account to nobody user
        my $guestSID = $self->ldb->domainSID() . '-501';
        my $guestGroupSID = $self->ldb->domainSID() . '-514';
        my $uid = getpwnam(EBox::Samba::Model::SambaShares::GUEST_DEFAULT_USER());
        my $gid = getgrnam(EBox::Samba::Model::SambaShares::GUEST_DEFAULT_GROUP());
        my $typeUID = EBox::LDB::IdMapDb::TYPE_UID();
        my $typeGID = EBox::LDB::IdMapDb::TYPE_UID();
        EBox::info("Mapping guest accounts");
        $self->ldb->idmap->setupNameMapping($guestSID, $typeUID, $uid);
        $self->ldb->idmap->setupNameMapping($guestGroupSID, $typeGID, $gid);

        EBox::debug('Setting provisioned flag');
        $self->setProvisioned(1);
    } otherwise {
        my $error = shift;
        $self->setProvisioned(0);
        $self->setupDNS(0);
        throw $error;
    } finally {
        # Revert primary resolver changes
        if (defined $dnsFile and -f $dnsFile) {
            EBox::Sudo::root("cp $dnsFile /etc/resolv.conf");
            unlink $dnsFile;
        }
    };
}

# Method: setupDNS
#
#   Modify the domain setup for samba or for users module
#
# Parameters:
#
#   dlz - If set to 1, the domain will be set up for samba, else it will be
#         set up for users module
#
sub setupDNS
{
    my ($self, $dlz) = @_;

    my $dnsModule = EBox::Global->modInstance('dns');
    my $sysinfo = EBox::Global->modInstance('sysinfo');

    # Ensure that the managed domain exists
    my $domainModel = $dnsModule->model('DomainTable');
    my $domainRow = $domainModel->find(domain => $sysinfo->hostDomain());
    unless (defined $domainRow) {
        throw EBox::Exceptions::Internal("Domain named '" . $sysinfo->hostDomain()
            . "' not found");
    }

    # Mark the domain as samba
    if ($dlz) {
        EBox::debug('Setting up DNS for samba');
        $domainRow->elementByName('samba')->setValue(1);
    } else {
        EBox::debug('Setting up DNS for users');
        $domainRow->elementByName('samba')->setValue(0);
    }
    $domainRow->store();

    # And force service restart
    $dnsModule->save();

    if (EBox::Sudo::fileTest('-f', SAMBA_DNS_KEYTAB)) {
        my @cmds;
        push (@cmds, "chgrp bind " . SAMBA_DNS_KEYTAB);
        push (@cmds, "chmod g+r " . SAMBA_DNS_KEYTAB);
        EBox::Sudo::root(@cmds);
    }
}

# Method: sambaInterfaces
#
#   Return interfaces upon samba should listen
#
sub sambaInterfaces
{
    my ($self) = @_;

    my @ifaces = ();
    # Always listen on loopback interface
    push (@ifaces, 'lo');

    my $net = EBox::Global->modInstance('network');

    my $listen_external = EBox::Config::configkey('listen_external');

    my $netIfaces;
    if ($listen_external eq 'yes') {
        $netIfaces = $net->allIfaces();
    } else {
        $netIfaces = $net->InternalIfaces();
    }

    foreach my $iface (@{$netIfaces}) {
        push @ifaces, $iface;

        if ($net->ifaceMethod($iface) eq 'bridged') {
            my $br = $net->ifaceBridge($iface);
            push (@ifaces, "br$br");
            next;
        }

        my $vifacesNames = $net->vifaceNames($iface);
        if (defined $vifacesNames) {
            push @ifaces, @{$vifacesNames};
        }
    }

    my @moduleGeneratedIfaces = ();
    push @ifaces, @moduleGeneratedIfaces;
    return \@ifaces;
}

sub writeSambaConfig
{
    my ($self) = @_;

    my $interfaces = join (',', @{$self->sambaInterfaces()});

    my $netbiosName = $self->netbiosName();
    my $realmName   = EBox::Global->modInstance('users')->kerberosRealm();

    my $prefix = EBox::Config::configkey('custom_prefix');
    $prefix = 'zentyal' unless $prefix;

    my @array = ();
    push (@array, 'fs'          => EBox::Config::configkey('samba_fs'));
    push (@array, 'prefix'      => $prefix);
    push (@array, 'workgroup'   => $self->workgroup());
    push (@array, 'netbiosName' => $netbiosName);
    push (@array, 'description' => $self->description());
    push (@array, 'ifaces'      => $interfaces);
    push (@array, 'mode'        => 'dc');
    push (@array, 'realm'       => $realmName);
    push (@array, 'roamingProfiles' => $self->roamingProfiles());
    push (@array, 'profilesPath' => PROFILES_DIR);

    push (@array, 'printers'  => $self->printersConf());

    #push(@array, 'backup_path' => EBox::Config::conf() . 'backups');

    my $shares = $self->shares();
    push (@array, 'shares' => $shares);
    foreach my $share (@{$shares}) {
        if ($share->{guest}) {
            push (@array, 'guestAccess' => 1);
            push (@array, 'guestAccount' => EBox::Samba::Model::SambaShares::GUEST_DEFAULT_USER());
            last;
        }
    }

    push (@array, 'antivirus' => $self->defaultAntivirusSettings());
    push (@array, 'antivirus_exceptions' => $self->antivirusExceptions());
    push (@array, 'antivirus_config' => $self->antivirusConfig());
    push (@array, 'recycle' => $self->defaultRecycleSettings());
    push (@array, 'recycle_exceptions' => $self->recycleExceptions());
    push (@array, 'recycle_config' => $self->recycleConfig());

    #my $netlogonDir = "/var/lib/samba/sysvol/" . $self->realm() . "/scripts";
    #if ($self->mode() eq 'dc') {
    #    #my $logonScript = join('/', $netlogonDir, LOGON_SCRIPT);
    #    #if (EBox::Sudo::fileTest('-f', $logonScript)) {
    #    #    push(@array, 'logon_script', LOGON_SCRIPT);
    #    #}
    #    $self->writeConfFile(join('/', $netlogonDir, LOGON_DEFAULT_SCRIPT),
    #        'samba/logon.bat.mas', \@array);
    #}

    $self->writeConfFile(SAMBACONFFILE,
                         'samba/smb.conf.mas', \@array);
}

sub _preSetConf
{
    my ($self) = @_;

    $self->stopService();
}

sub _setupQuarantineDirectory
{
    my ($self) = @_;

    my $quarantineDir = EBox::Config::configkey('quarantine_dir');
    my $group = EBox::UsersAndGroups::DEFAULTGROUP();
    my $nobody = EBox::Samba::Model::SambaShares::GUEST_DEFAULT_USER();
    my @cmds = ("mkdir -p '$quarantineDir'",
                "chown root:$group '$quarantineDir'",
                "chmod 700 '$quarantineDir'",
                "setfacl -R -m u:$nobody:wx g:$group:wx '$quarantineDir'");
    # Grant access to domain admins
    my $domainAdminsSid = $self->ldb->domainSID() . '-512';
    my $domainAdminsGroup = new EBox::Samba::Group(sid => $domainAdminsSid);
    if ($domainAdminsGroup->exists()) {
        my @domainAdmins = $domainAdminsGroup->get('member');
        foreach my $memberDN (@domainAdmins) {
            my $user = new EBox::Samba::User(dn => $memberDN);
            if ($user->exists()) {
                my $uid = $user->get('samAccountName');
                push (@cmds, "setfacl -m u:$uid:rwx '$quarantineDir'");
            }
        }
    }
    EBox::Sudo::silentRoot(@cmds);
}

sub _setConf
{
    my ($self) = @_;

    return unless $self->configured() and $self->isEnabled();

    $self->provision() unless $self->isProvisioned();

    $self->writeSambaConfig();

    # Remove shares
    $self->model('SambaDeletedShares')->removeDirs();
    # Create shares
    $self->model('SambaShares')->createDirs();

    # Change group ownership of quarantine_dir to __USERS__
    if ($self->defaultAntivirusSettings()) {
        $self->_setupQuarantineDirectory();
    }

    my $netbiosName = $self->netbiosName();
    my $realmName = EBox::Global->modInstance('users')->kerberosRealm();
    my $users = $self->ldb->users();
    foreach my $user (@{$users}) {
        # Set roaming profiles
        if ($self->roamingProfiles()) {
            my $path = "\\\\$netbiosName.$realmName\\profiles";
            $user->setRoamingProfile(1, $path, 1);
        } else {
            $user->setRoamingProfile(0);
        }

        # Mount user home on network drive
        my $drivePath = "\\\\$netbiosName.$realmName";
        $user->setHomeDrive($self->drive(), $drivePath, 1);
        $user->save();
    }
}

sub printersConf
{
    my ($self) = @_;

    my $printers = [];
    if (EBox::Global->modExists('printers')) {
        my $printersModule = EBox::Global->modInstance('printers');
        if ($printersModule->isEnabled()) {
            my $printersModel = $printersModule->model('Printers');
            my $ids = $printersModel->ids();
            foreach my $id (@{$ids}) {
                my $row = $printersModel->row($id);
                my $printerName = $row->valueByName('printer');
                my $printerGuest = $row->valueByName('guest');
                my $printerDescription = $row->valueByName('description');
                # Get the allowed users and groups for this printer if guest
                # access is disabled
                my $printerAcl = [];
                for my $subId (@{$row->subModel('access')->ids()}) {
                    my $subRow = $row->subModel('access')->row($subId);
                    my $userType = $subRow->elementByName('user_group');
                    my $preCar = $userType->selectedType() eq 'group' ? '@' : '';
                    my $user =  $preCar . '"' . $userType->printableValue() . '"';
                    push (@{$printerAcl}, $user);
                }
                push (@{$printers}, {
                    name => $printerName,
                    description => $printerDescription,
                    guest => $printerGuest,
                    acl => $printerAcl,
                } );
            }
        }
    }

    return $printers;
}

# Method: _daemons
#
#       Override EBox::Module::Service::_daemons
#
sub _daemons
{
    return [
        {
            name => 'samba4',
            pidfiles => ['/var/run/samba.pid'],
        },
        {
            name => 'zentyal.s4sync',
            precondition => \&isProvisioned,
        },
    ];
}

# Function: usesPort
#
#   Implements EBox::FirewallObserver interface
#
sub usesPort
{
    my ($self, $protocol, $port, $iface) = @_;

    return undef unless($self->isEnabled());

    foreach my $smbport (@{$self->_services()}) {
        return 1 if ($port eq $smbport->{destinationPort});
    }

    return undef;
}

sub firewallHelper
{
    my ($self) = @_;

    if ($self->isEnabled()) {
        return new EBox::SambaFirewall();
    }
    return undef;
}

# Method: firewallCaptivePortalExceptions
#
#  this method gives firewall ruels to add to the captive portal module.
#  They purpose is to allow domain joins without captive portal interference
sub firewallCaptivePortalExceptions
{
    my ($self) = @_;
    my @rules;

    if (not $self->isEnabled()) {
       return [];
    }

     my @services = @{ $self->_services() };
    foreach my $conf (@services) {
        my $args = '';
        my $tcpAndUdp = 0;
        if ($conf->{protocol} ne 'any') {
            if ($conf->{protocol} eq 'tcp/udp') {
                $tcpAndUdp = 1;
            } else {
                $args .= '--protocol ' . $conf->{protocol};
            }
        }
        if ($conf->{sourcePort} ne 'any') {
            $args .= ' --sport ' . $conf->{sourcePort};
        }
        if ($conf->{destinationPort} ne 'any') {
            $args .= ' --dport ' . $conf->{destinationPort};
        }

        if ($args) {
            if ($tcpAndUdp) {
                push @rules, "--protocol tcp $args -j RETURN";
                push @rules, "--protocol udp $args -j RETURN";
            } else {
                push @rules, "$args -j RETURN";
            }
        }
    }

    return \@rules;
}


sub menu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('url' => 'Samba/Composite/General',
                                    'text' => $self->printableName(),
                                    'separator' => 'Office',
                                    'order' => 540));
}

# Method: administratorPassword
#
#   Returns the administrator password
#
sub administratorPassword
{
    my ($self) = @_;

    my $pwdFile = EBox::Config::conf() . 'samba.passwd';

    my $pass;
    unless (-f $pwdFile) {
        my $pass;

        while (1) {
            $pass = EBox::Util::Random::generate(20);
            # Check if the password meet the complexity constraints
            last if ($pass =~ /[a-z]+/ and $pass =~ /[A-Z]+/ and
                     $pass =~ /[0-9]+/ and length ($pass) >=8);
        }

        my (undef, undef, $uid, $gid) = getpwnam('ebox');
        EBox::Module::Base::writeFile($pwdFile, $pass, { mode => '0600', uid => $uid, gid => $gid });
        return $pass;
    }

    return read_file($pwdFile);
}

# Method: defaultNetbios
#
#   Generates the default netbios server name
#
sub defaultNetbios
{
    my ($self) = @_;

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $hostName = $sysinfo->hostName();

    return $hostName;
}

# Method: netbiosName
#
#   Returns the configured netbios name
#
sub netbiosName
{
    my ($self) = @_;

    my $model = $self->model('GeneralSettings');
    return $model->netbiosNameValue();
}

# Method: defaultWorkgroup
#
#   Generates the default workgroup
#
sub defaultWorkgroup
{
    my $users = EBox::Global->modInstance('users');
    my $realm = $users->kerberosRealm();
    my @parts = split (/\./, $realm);
    my $value = $parts[0];
    $value = 'ZENTYAL-DOMAIN' unless defined $value;

    return uc($value);
}

# Method: workgroup
#
#   Returns the configured workgroup name
#
sub workgroup
{
    my ($self) = @_;

    my $model = $self->model('GeneralSettings');
    return $model->workgroupValue();
}

# Method: defaultDescription
#
#   Generates the default server string
#
sub defaultDescription
{
    my $prefix = EBox::Config::configkey('custom_prefix');
    $prefix = 'zentyal' unless $prefix;

    return ucfirst($prefix) . ' File Server';
}

# Method: description
#
#   Returns the configured description string
#
sub description
{
    my ($self) = @_;

    my $model = $self->model('GeneralSettings');
    return $model->descriptionValue();
}

# Method: roamingProfiles
#
#   Returns if roaming profiles are enabled
#
sub roamingProfiles
{
    my ($self) = @_;

    my $model = $self->model('GeneralSettings');
    return $model->roamingValue();
}

# Method: mode
#
#   Returns the configured server mode
#
sub mode
{
    my ($self) = @_;

    my $model = $self->model('GeneralSettings');
    return $model->modeValue();
}

# Method: drive
#
#   Returns the configured drive letter
#
sub drive
{
    my ($self) = @_;

    my $model = $self->model('GeneralSettings');
    return $model->driveValue();
}

# Method: _ldapModImplementation
#
#   LdapModule implmentation
#
sub _ldapModImplementation
{
    my $self;

    return new EBox::SambaLdapUser();
}

sub dumpConfig
{
    my ($self, $dir, %options) = @_;

    # Remove previous backup files
    my $privateDir = PRIVATE_DIR;
    my $bakFiles = EBox::Sudo::root("find $privateDir -name '*.ldb.bak'");
    foreach my $bakFile (@{$bakFiles}) {
        chomp ($bakFile);
        EBox::Sudo::root("rm '$bakFile'");
    }

    try {
        # The service must be stopped or tar may fail with
        # file changed as we read it
        $self->stopService();

        # Backup private. LDB files must be backed up using tdbbackup
        my $ldbFiles = EBox::Sudo::root("find $privateDir -name '*.ldb'");
        foreach my $ldbFile (@{$ldbFiles}) {
            chomp ($ldbFile);
            EBox::Sudo::root("tdbbackup '$ldbFile'");
            # Preserve file permissions
            my $st = EBox::Sudo::stat($ldbFile);
            my $uid = $st->uid();
            my $gid = $st->gid();
            my $mode = sprintf ("%04o", $st->mode() & 07777);
            EBox::Sudo::root("chown $uid:$gid $ldbFile.bak");
            EBox::Sudo::root("chmod $mode $ldbFile.bak");
        }
        EBox::Sudo::root("tar cjf $dir/private.tar.bz2 $privateDir --exclude=*.ldb");

        # Backup sysvol
        my $sysvolDir = SYSVOL_DIR;
        EBox::Sudo::root("tar cjf $dir/sysvol.tar.bz2 $sysvolDir");
    } otherwise {
        my ($error) = @_;
        throw $error;
    } finally {
        $self->_startService();
    };

    # Backup admin password
    unless ($options{bug}) {
        my $pwdFile = EBox::Config::conf() . 'samba.passwd';
        EBox::Sudo::root("cp '$pwdFile' $dir");
    }
}

sub restoreConfig
{
    my ($self, $dir) = @_;

    my $mode = $self->mode();
    unless ($mode eq EBox::Samba::Model::GeneralSettings::MODE_DC()) {
        # Restoring an ADC will corrupt entire domain as sync data
        # get out of sync.
        EBox::info(__("Restore is only possible if the server is the unique " .
                      "domain controller of the forest"));
        $self->setProvisioned(0);
        return;
    }

    $self->stopService();

    # Remove private and sysvol
    my $privateDir = PRIVATE_DIR;
    my $sysvolDir = SYSVOL_DIR;
    EBox::Sudo::root("rm -rf $privateDir/* $sysvolDir/*");

    # Unpack sysvol
    EBox::Sudo::root("tar jxfp $dir/sysvol.tar.bz2 -C /");

    # Unpack private folder
    EBox::Sudo::root("tar jxfp $dir/private.tar.bz2 -C /");

    # Rename ldb files
    my $bakFiles = EBox::Sudo::root("find $privateDir -name '*.ldb.bak'");
    foreach my $bakFile (@{$bakFiles}) {
        chomp $bakFile;
        my $destFile = $bakFile;
        $destFile =~ s/\.bak$//;
        EBox::Sudo::root("mv '$bakFile' '$destFile'");
    }

    # Restore stashed password
    EBox::Sudo::root("cp $dir/samba.passwd " . EBox::Config::conf());
    EBox::Sudo::root("chmod 0600 $dir/samba.passwd");

    # Set provisioned flag
    $self->setProvisioned(1);

    $self->_startService();
}

sub restoreDependencies
{
    my @depends = ();

    push (@depends, 'users');

    if (EBox::Global->modExists('printers')) {
        push (@depends, 'printers');
    }

    return \@depends;
}


# backup domains

#sub backupDomains
#{
#    my $name = 'shares';
#    my %attrs  = (
#                  printableName => __('File Sharing'),
#                  description   => __(q{Shares, users and groups homes and profiles}),
#                 );
#
#    return ($name, \%attrs);
#}

#sub backupDomainsFileSelection
#{
#    my ($self, %enabled) = @_;
#    if ($enabled{shares}) {
#        my $sambaLdapUser = new EBox::SambaLdapUser();
#        my @dirs = @{ $sambaLdapUser->sharedDirectories() };
#        push @dirs, map {
#            $_->{path}
#        } @{ $self->shares(1) };
#
#        my $selection = {
#                          includes => \@dirs,
#                         };
#        return $selection;
#    }
#
#    return {};
#}

# Overrides:
#   EBox::Report::DiskUsageProvider::_facilitiesForDiskUsage
#sub _facilitiesForDiskUsage
#{
#    my ($self) = @_;
#
#    my $usersPrintableName  = __(q{Users files});
#    my $usersPath           = EBox::SambaLdapUser::usersPath();
#    my $groupsPrintableName = __(q{Groups files});
#    my $groupsPath          = EBox::SambaLdapUser::groupsPath();
#
#    return {
#        $usersPrintableName   => [ $usersPath ],
#        $groupsPrintableName  => [ $groupsPath ],
#    };
#}

# Implement LogHelper interface
sub tableInfo
{
    my ($self) = @_;

    my $access_titles = {
        'timestamp' => __('Date'),
        'client' => __('Client address'),
        'username' => __('User'),
        'event' => __('Action'),
        'resource' => __('Resource'),
    };
    my @access_order = qw(timestamp client username event resource);
    my $access_events = {
        'connect' => __('Connect'),
        'opendir' => __('Access to directory'),
        'readfile' => __('Read file'),
        'writefile' => __('Write file'),
        'disconnect' => __('Disconnect'),
        'unlink' => __('Remove'),
        'mkdir' => __('Create directory'),
        'rmdir' => __('Remove directory'),
        'rename' => __('Rename'),
    };

    my $virus_titles = {
        'timestamp' => __('Date'),
        'client' => __('Client address'),
        'filename' => __('File name'),
        'virus' => __('Virus'),
        'event' => __('Type'),
    };
    my @virus_order = qw(timestamp client filename virus event);;
    my $virus_events = { 'virus' => __('Virus') };

    my $quarantine_titles = {
        'timestamp' => __('Date'),
        'filename' => __('File name'),
        'qfilename' => __('Quarantined file name'),
        'event' => __('Quarantine'),
    };
    my @quarantine_order = qw(timestamp filename qfilename event);
    my $quarantine_events = { 'quarantine' => __('Quarantine') };

    return [{
        'name' => __('Samba access'),
        'tablename' => 'samba_access',
        'titles' => $access_titles,
        'order' => \@access_order,
        'timecol' => 'timestamp',
        'filter' => ['client', 'username', 'resource'],
        'types' => { 'client' => 'IPAddr' },
        'events' => $access_events,
        'eventcol' => 'event'
    },
    {
        'name' => __('Samba virus'),
        'tablename' => 'samba_virus',
        'titles' => $virus_titles,
        'order' => \@virus_order,
        'timecol' => 'timestamp',
        'filter' => ['client', 'filename', 'virus'],
        'types' => { 'client' => 'IPAddr' },
        'events' => $virus_events,
        'eventcol' => 'event'
    },
    {
        'name' => __('Samba quarantine'),
        'tablename' => 'samba_quarantine',
        'titles' => $quarantine_titles,
        'order' => \@quarantine_order,
        'timecol' => 'timestamp',
        'filter' => ['filename'],
        'events' => $quarantine_events,
        'eventcol' => 'event'
    }];
}

sub logHelper
{
    my ($self) = @_;

    return (new EBox::SambaLogHelper);
}

#sub report
#{
#    my ($self, $beg, $end, $options) = @_;
#    my $maxTopActivityUsers = $options->{'max_top_activity_users'};
#    my $maxTopActivityGroups = $options->{'max_top_activity_groups'};
#    my $maxTopSizeShares = $options->{'max_top_size_shares'};
#    my $maxTopVirusShares = $options->{'max_top_virus_shares'};
#
#    my $report = {};
#
#    $report->{'activity'} = $self->runMonthlyQuery($beg, $end, {
#        'select' => 'COALESCE(SUM(operations), 0) AS OPERATIONS',
#        'from' => 'samba_access_report'
#    });
#
#    $report->{'top_activity_users'} = $self->runQuery($beg, $end, {
#        'select' => 'username, SUM(operations) AS operations',
#        'from' => 'samba_access_report',
#        'group' => 'username',
#        'limit' => $maxTopActivityUsers,
#        'order' => 'operations DESC'
#    });
#
#
#    $report->{top_activity_groups} = _topActivityGroups($self, $beg, $end, $maxTopActivityGroups);
#
#    $report->{'top_size_shares'} = $self->runQuery($beg, $end, {
#        'select' => 'share, type, AVG(size) AS size',
#        'from' => 'samba_disk_usage_report',
#        'group' => 'share, type',
#        'limit' => $maxTopSizeShares,
#        'order' => 'size DESC',
#    });
#
#    $report->{'top_size_user_shares'} = $self->runQuery($beg, $end, {
#        'select' => 'share, AVG(size) AS size',
#        'from' => 'samba_disk_usage_report',
#        'group' => 'share',
#        'limit' => $maxTopSizeShares,
#        'order' => 'size DESC',
#        'where' => q{type = 'user'}
#    });
#
#    $report->{'top_size_group_shares'} = $self->runQuery($beg, $end, {
#        'select' => 'share, AVG(size) AS size',
#        'from' => 'samba_disk_usage_report',
#        'group' => 'share, type',
#        'limit' => $maxTopSizeShares,
#        'order' => 'size DESC',
#        'where' => q{type = 'group'}
#    });
#
#    $report->{'top_size_custom_shares'} = $self->runQuery($beg, $end, {
#        'select' => 'share, AVG(size) AS size',
#        'from' => 'samba_disk_usage_report',
#        'group' => 'share, type',
#        'limit' => $maxTopSizeShares,
#        'order' => 'size DESC',
#        'where' => q{type = 'custom'}
#    });
#
#    $report->{'top_virus_shares'} = $self->runQuery($beg, $end, {
#        'select' => 'share, SUM(virus) as virus',
#        'from' => 'samba_virus_share_report',
#        'group' => 'share',
#        'limit' => $maxTopVirusShares,
#        'order' => 'virus DESC',
#    });
#
#
#    return $report;
#}
#
#sub _topActivityGroups
#{
#    my ($self, $beg, $end, $maxTopActivityGroups) = @_;
#    my $usersMod = EBox::Global->modInstance('users');
#
#    my $sqlResult = $self->runQuery($beg, $end, {
#        'select' => 'username, SUM(operations) AS operations',
#        'from' => 'samba_access_report',
#        'group' => 'username',
#    });
#    my %operationsByUser;
#    foreach my $i (0 .. $#{ $sqlResult->{username} } ) {
#        $operationsByUser{ $sqlResult->{username}->[$i] } =  $sqlResult->{operations}->[$i];
#    }
#
#    delete $sqlResult->{username};
#    delete $sqlResult->{operations};
#
#
#    my $min = -1;
#    my @groupsAndOperations;
#    foreach my $group_r ($usersMod->groups()) {
#        my $groupname = $group_r->{account};
#        my $operations = 0;
#
#        my @users = @{ $usersMod->usersInGroup($groupname) };
#        foreach my $user (@users) {
#            $operations += $operationsByUser{$user};
#        }
#
#
#        if (@groupsAndOperations <   $maxTopActivityGroups ) {
#            push @groupsAndOperations, [$groupname => $operations];
#        } elsif ($operations > $min) {
#            pop @groupsAndOperations;
#            push @groupsAndOperations, [$groupname => $operations];
#        } else {
#            next;
#        }
#
#        @groupsAndOperations = sort { $b->[1] <=> $a->[1]  } @groupsAndOperations;
#        $min = $groupsAndOperations[-1]->[1];
#    }
#
#    my @topGroups     = map { $_->[0]  } @groupsAndOperations;
#    my @topOperations = map { $_->[1] } @groupsAndOperations;
#    return {
#            'groupname' => \@topGroups,
#            'operations' => \@topOperations,
#           };
#}
#
#sub consolidateReportQueries
#{
#    return [
#        {
#            'target_table' => 'samba_access_report',
#            'query' => {
#                'select' => 'username, COUNT(event) AS operations',
#                'from' => 'samba_access',
#                'group' => 'username'
#            },
#            quote => { username => 1 },
#        },
#        {
#            'target_table' => 'samba_virus_report',
#            'query' => {
#                'select' => 'client, COUNT(event) AS virus',
#                'from' => 'samba_virus',
#                'group' => 'client'
#            },
#            quote => { client => 1 },
#        },
#        {
#            'target_table' => 'samba_disk_usage_report',
#            'query' => {
#                'select' => 'share, type, CAST (AVG(size) AS int) AS size',
#                'from' => 'samba_disk_usage',
#                'group' => 'share, type'
#
#            },
#            quote => { share => 1 },
#        },
#        {
#            'target_table' => 'samba_virus_share_report',
#            'query' => {
#                'select' => 'share, count(*) as virus',
#                'from' => 'samba_quarantine',
#                'where' => q{event='quarantine'},
#                'group' => 'filename'
#            },
#            'rowConversor' => \&_virusShareReportRowConversor,
#            'targetGroupFields' => ['share'],
#            quote => { share => 1 },
#        },
#    ];
#}
#
#my @sharesSortedByPathLen;
#
#sub _updatePathsByLen
#{
#    my ($self) = @_;
#
#    my $ldapInfo = EBox::SambaLdapUser->new();
#    @sharesSortedByPathLen = map {
#         { path => $_->{path},
#           share => $_->{sharename} }
#    } ( @{ $ldapInfo->userShareDirectories },
#        @{ $ldapInfo->groupShareDirectories }
#      );
#
#    foreach my $sh_r (@{ $self->shares(1) }) {
#        push @sharesSortedByPathLen, {path => $sh_r->{path},
#                                      share =>  $sh_r->{share} };
#    }
#
#    # add regexes
#    foreach my $share (@sharesSortedByPathLen) {
#        my $path = $share->{path};
#        $share->{pathRegex} = qr{^$path/};
#    }
#
#    @sharesSortedByPathLen = sort {
#        length($b->{path}) <=>  length($a->{path})
#    } @sharesSortedByPathLen;
#}
#
#sub _shareByFilename
#{
#    my ($filename) = @_;
#
#    if (not @sharesSortedByPathLen) {
#        my $samba =EBox::Global->modInstance('samba');
#        $samba->_updatePathsByLen();
#    }
#
#
#    foreach my $shareAndPath (@sharesSortedByPathLen) {
#        if ($filename =~ m/$shareAndPath->{pathRegex}/) {
#            return $shareAndPath->{share};
#        }
#    }
#
#
#    return undef;
#}
#
#sub _virusShareReportRowConversor
#{
#    my ($row) = @_;
#    my $filename = delete $row->{filename};
#    my $share = _shareByFilename($filename);
#    EBox::debug("COBV $filename -> $share");
#    if ($share) {
#        $row->{share} = $share;
#    } else {
#        return undef;
#    }
#
#
#    return $row;
#}
#
#sub logReportInfo
#{
#    my ($self) = @_;
#
#    if ($self->_diskUsageAlreadyCheckedToday) {
#        return [];
#    }
#
#    my @reportData;
#
#    my %shareByPath;
#
#    my @shares = @{ $self->_sharesAndSizes() };
#
#
#    foreach my $share (@shares) {
#        # add info about disk usage by share
#        my $entry = {
#                     table => 'samba_disk_usage',
#                     values => {
#                                share => $share->{share},
#                                size  => $share->{size},
#                                type  => $share->{type},
#                               }
#                    };
#        push @reportData, $entry;
#    }
#
#    return \@reportData;
#}
#
#sub _diskUsageAlreadyCheckedToday
#{
#    my ($self) = @_;
#
#    my $db = EBox::DBEngineFactory::DBEngine();
#    my $query = q{SELECT share FROM samba_disk_usage WHERE (timestamp >= (current_date + interval '0 day')) AND (timestamp < (current_date + interval '1 day'))};
#    my $results = $db->query($query);
#    return @{ $results } > 0;
#}
#
#sub _sharesAndSizes
#{
#    my ($self) = @_;
#
#    my $ldapInfo = EBox::SambaLdapUser->new();
#    my @shares;
#
#    foreach my $sh_r ( @{ $ldapInfo->userShareDirectories }) {
#        my $share = {
#                     share => $sh_r->{sharename},
#                     path  => $sh_r->{path},
#                     type  => 'user',
#                    };
#        push @shares, $share;
#    }
#
#    foreach my $sh_r ( @{ $ldapInfo->groupShareDirectories }) {
#        my $share = {
#                     share => $sh_r->{sharename},
#                     path  => $sh_r->{path},
#                     type  => 'group',
#                    };
#        push @shares, $share;
#    }
#
#    # add no-account shares to share list
#    foreach my $sh_r (@{ $self->shares(1)  }) {
#        my $share = {
#                     share => $sh_r->{share},
#                     path  => $sh_r->{path},
#                     type  => 'custom',
#                    };
#        push @shares, $share;
#    }
#
#
#    foreach my $share (@shares) {
#        my $path = $share->{path};
#        if (EBox::Sudo::fileTest('-d', $path)) {
#            my $output = EBox::Sudo::rootWithoutException("du -ms '$path'");
#
#            my ($size) =  $output->[0] =~ m{^(\d+)};
#            if (not defined $size) {
#                EBox::error("Problem getting $path size: @{$output}");
#                $size = 0;
#            }
#
#            $share->{size} = $size;
#        }
#    }
#
#    return \@shares;
#}

# Method: ldb
#
#   Provides an EBox::LDB object with the proper settings
#
sub ldb
{
    my ($self) = @_;

    unless (defined ($self->{ldb})) {
        $self->{ldb} = EBox::LDB->instance();
    }
    return $self->{ldb};
}

# Method: sharesPaths
#
#   This function is used to generate disk usage reports. It
#   returns the shares paths, excluding the group shares.
#
sub sharesPaths
{
    my ($self) = @_;

    my $shares = $self->shares(1);
    my $paths = [];

    foreach my $share (@{$shares}) {
        push (@{$paths}, $share->{path}) unless defined $share->{groupShare};
    }

    return $paths;
}

# Method: userShares
#
#   This function is used to generate disk usage reports. It
#   returns all the users with their shares
#
#   Returns:
#       Array ref with hash refs containing:
#           - 'user' - String the username
#           - 'shares' - Array ref with all the shares for this user
#
sub userShares
{
    my ($self) = @_;

    my $userProfilesPath = EBox::SambaLdapUser::PROFILESPATH();

    my $usersMod = EBox::Global->modInstance('users');
    my $users = $usersMod->users();

    my $shares = [];
    foreach my $user (@{$users}) {
        my $userProfilePath = $userProfilesPath . "/" . $user->get('uid');

        my $userShareInfo = {
            'user' => $user->name(),
            'shares' => [$user->get('homeDirectory'), $userProfilePath],
        };
        push (@{$shares}, $userShareInfo);
    }

    return $shares;
}

# Method: groupPaths
#
#   This function is used to generate disk usage reports. It
#   returns the group share path if it is configured.
#
sub groupPaths
{
    my ($self, $group) = @_;

    my $groupName = $group->get('cn');
    my $shares = $self->shares(1);
    my $paths = [];

    foreach my $share (@{$shares}) {
        if (defined $groupName and defined $share->{groupShare} and
            $groupName eq $share->{groupShare}) {
            push (@{$paths}, $share->{path});
            last;
        }
    }

    return $paths;
}

my @sharesSortedByPathLen;

sub _updatePathsByLen
{
    my ($self) = @_;

    # FIXME: Complete the implementation
    @sharesSortedByPathLen = ();

    foreach my $sh_r (@{ $self->shares(1) }) {
        push @sharesSortedByPathLen, {path => $sh_r->{path},
                                      share =>  $sh_r->{share} };
    }

    # add regexes
    foreach my $share (@sharesSortedByPathLen) {
        my $path = $share->{path};
        $share->{pathRegex} = qr{^$path/};
    }

    @sharesSortedByPathLen = sort {
        length($b->{path}) <=>  length($a->{path})
    } @sharesSortedByPathLen;
}

sub shareByFilename
{
    my ($filename) = @_;

    if (not @sharesSortedByPathLen) {
        my $samba =EBox::Global->modInstance('samba');
        $samba->_updatePathsByLen();
    }

    foreach my $shareAndPath (@sharesSortedByPathLen) {
        if ($filename =~ m/$shareAndPath->{pathRegex}/) {
            return $shareAndPath->{share};
        }
    }

    return undef;
}

1;
