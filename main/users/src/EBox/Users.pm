# Copyright (C) 2008-2014 Zentyal S.L.
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

use strict;
use warnings;

package EBox::Users;

use base qw(EBox::Module::LDAP
            EBox::SysInfo::Observer
            EBox::UserCorner::Provider
            EBox::SyncFolders::Provider
            EBox::Users::SyncProvider
            EBox::Report::DiskUsageProvider);

use EBox::Global;
use EBox::Util::Random;
use EBox::Ldap;
use EBox::Gettext;
use EBox::Menu::Folder;
use EBox::Menu::Item;
use EBox::Sudo;
use EBox::FileSystem;
use EBox::LdapUserImplementation;
use EBox::Config;
use EBox::Users::Computer;
use EBox::Users::Contact;
use EBox::Users::Group;
use EBox::Users::NamingContext;
use EBox::Users::OU;
use EBox::Users::Container;
use EBox::Users::Slave;
use EBox::Users::User;
use EBox::Users::GPO;
use EBox::UsersSync::Master;
use EBox::UsersSync::Slave;
use EBox::CloudSync::Slave;
use EBox::Exceptions::UnwillingToPerform;
use EBox::Exceptions::LDAP;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::SyncFolders::Folder;
use EBox::Util::Version;
use EBox::Users::NamingContext;
use EBox::Users::Provision;
use EBox::Users::DMD;

use Digest::SHA;
use Digest::MD5;
use Sys::Hostname;

use TryCatch::Lite;
use Net::LDAP::Control::Sort;
use File::Copy;
use File::Slurp;
use File::Temp qw/tempfile/;
use Perl6::Junction qw(any);
use String::ShellQuote;
use Time::HiRes;
use Fcntl qw(:flock);

use constant SAMBA_DIR            => '/home/samba/';
use constant SAMBATOOL            => '/usr/bin/samba-tool';
use constant SAMBACONFFILE        => '/etc/samba/smb.conf';
use constant PRIVATE_DIR          => '/var/lib/samba/private/';
use constant SAMBA_DNS_ZONE       => PRIVATE_DIR . 'named.conf';
use constant SAMBA_DNS_POLICY     => PRIVATE_DIR . 'named.conf.update';
use constant SAMBA_DNS_KEYTAB     => PRIVATE_DIR . 'dns.keytab';
use constant SECRETS_KEYTAB       => PRIVATE_DIR . 'secrets.keytab';
use constant SAM_DB               => PRIVATE_DIR . 'sam.ldb';
use constant SAMBA_PRIVILEGED_SOCKET => PRIVATE_DIR . '/ldap_priv';
use constant FSTAB_FILE           => '/etc/fstab';
use constant SYSVOL_DIR           => '/var/lib/samba/sysvol';
use constant PROFILES_DIR         => SAMBA_DIR . 'profiles';
use constant ANTIVIRUS_CONF       => '/var/lib/zentyal/conf/samba-antivirus.conf';
use constant GUEST_DEFAULT_USER   => 'nobody';
use constant SAMBA_DNS_UPDATE_LIST => PRIVATE_DIR . 'dns_update_list';

use constant COMPUTERSDN    => 'ou=Computers';
use constant AD_COMPUTERSDN => 'cn=Computers';

use constant STANDALONE_MODE      => 'master';
use constant EXTERNAL_AD_MODE     => 'external-ad';
use constant BACKUP_MODE_FILE     => 'LDAP_MODE.bak';

use constant DEFAULTGROUP   => 'Domain Users';
use constant JOURNAL_DIR    => EBox::Config::home() . 'syncjournal/';
use constant AUTHCONFIGTMPL => '/etc/auth-client-config/profile.d/acc-zentyal';
use constant CRONFILE       => '/etc/cron.d/zentyal-users';
use constant CRONFILE_EXTERNAL_AD_MODE => '/etc/cron.daily/zentyal-users-external-ad';

use constant SAMBACONFFILE        => '/etc/samba/smb.conf';
use constant PRIVATE_DIR          => '/var/lib/samba/private/';
use constant SYSVOL_DIR           => '/var/lib/samba/sysvol';

# Kerberos constants
use constant KERBEROS_PORT => 88;
use constant KPASSWD_PORT => 464;
use constant KRB5_CONF_FILE => '/var/lib/samba/private/krb5.conf';
use constant SYSTEM_WIDE_KRB5_CONF_FILE => '/etc/krb5.conf';

# SSSD conf
use constant SSSD_CONF_FILE => '/etc/sssd/sssd.conf';

use constant OBJECT_EXISTS => 1;
use constant OBJECT_EXISTS_AND_HIDDEN_SID => 2;


sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'users',
                                      printableName => __('Users and Computers'),
                                      @_);
    bless($self, $class);
    $self->_setupForMode();

    return $self;
}

# Method: _setupForMode
#
#   setup the internal attributes need for active authentication mode
#
sub _setupForMode
{
    my ($self) = @_;
    my $mode = $self->mode();
    if ($mode ne EXTERNAL_AD_MODE) {
        $self->{ldapClass} = 'EBox::Ldap';
        $self->{ouClass} = 'EBox::Users::OU';
        $self->{userClass} = 'EBox::Users::User';
        $self->{contactClass} = 'EBox::Users::Contact';
        $self->{groupClass} = 'EBox::Users::Group';
        $self->{containerClass} = 'EBox::Users::Container';
    } else {
        $self->{ldapClass} = 'EBox::LDAP::ExternalAD';
        $self->{ouClass} = 'EBox::Users::OU::ExternalAD';
        $self->{userClass} = 'EBox::Users::User::ExternalAD';
        $self->{contactClass} = 'EBox::Users::Contact::ExternalAD';
        $self->{groupClass} = 'EBox::Users::Group::ExternalAD';
        $self->{containerClass} = 'EBox::Users::Container::ExternalAD';
        # load this classes only when needed
        foreach my $pkg ($self->{ldapClass}, $self->{ouClass}, $self->{userClass}, $self->{contactClass}, $self->{groupClass}, $self->{containerClass}) {
            eval "use $pkg";
            $@ and throw EBox::Exceptions::Internal("When loading $pkg: $@");
        }
    }

}

# Method: ldb
#
#   Provides an EBox::Ldap object with the proper settings
#
sub ldb
{
    my ($self) = @_;
    EBox::debug("ldb() to be deprecated, replace with ldap()");
    return $self->ldap();
}


# Method: ldapClass
#
#   Return the LDAP class implementation to use.
#
sub ldapClass
{
    my ($self) = @_;

    (defined $self->{ldapClass}) or
        throw EBox::Exceptions::Internal("ldapClass not initialized.");

    return $self->{ldapClass};
}

# Method: ouClass
#
#   Return the OU class implementation to use.
#
sub ouClass
{
    my ($self) = @_;

    (defined $self->{ouClass}) or
        throw EBox::Exceptions::Internal("ouClass not initialized.");

    return $self->{ouClass};
}

# Method: userClass
#
#   Return the User class implementation to use.
#
sub userClass
{
    my ($self) = @_;

    (defined $self->{userClass}) or
        throw EBox::Exceptions::Internal("userClass not initialized.");

    return $self->{userClass};
}

# Method: contactClass
#
#   Return the Contact class implementation to use.
#
sub contactClass
{
    my ($self) = @_;

    (defined $self->{contactClass}) or
        throw EBox::Exceptions::Internal("contactClass not initialized.");

    return $self->{contactClass};
}

# Method: groupClass
#
#   Return the Group class implementation to use.
#
sub groupClass
{
    my ($self) = @_;

    (defined $self->{groupClass}) or
        throw EBox::Exceptions::Internal("groupClass not initialized.") ;

    return $self->{groupClass};
}

# Method: container
#
#   Return the Container class implementation to use.
#
#  Warning:
#    this can be undefined since standalone server does not use it
sub containerClass
{
    my ($self) = @_;
    return $self->{containerClass};
}

# Method: actions
#
#       Override EBox::ServiceModule::ServiceInterface::actions
#
sub actions
{
    my ($self) = @_;

    my @actions;

    if ($self->mode() eq STANDALONE_MODE) {
        push@actions,{
                 'action' => __('Your LDAP database will be populated with some basic organizational units'),
                 'reason' => __('Zentyal needs this organizational units to add users and groups into them.'),
                 'module' => 'users'
                };

        # FIXME: This probably won't work if PAM is enabled after enabling the module
        if ($self->model('PAM')->enable_pamValue()) {
            push @actions, {
                    'action' => __('Configure PAM.'),
                    'reason' => __('Zentyal will give LDAP users system account.'),
                    'module' => 'users'
                };
        }
    }

    return \@actions;
}

# Method: usedFiles
#
#       Override EBox::Module::Service::files
#
sub usedFiles
{
    my ($self) = @_;
    my @files = ();
    push @files, {
            'file'   => SYSTEM_WIDE_KRB5_CONF_FILE,
            'reason' => __('To set up kerberos authentication'),
            'module' => 'users'
        };

    if ($self->mode() eq STANDALONE_MODE) {
        push @files, (
            {
                'file' => '/etc/nsswitch.conf',
                'reason' => __('To make NSS use LDAP resolution for user and '.
                               'group accounts. Needed for Samba PDC configuration.'),
                'module' => 'users'
            },
            {
                'file' => '/etc/fstab',
                'reason' => __('To add quota support to /home partition.'),
                'module' => 'users'
            },
            {
                'file' => SSSD_CONF_FILE,
                'reason' => __('To configure System Security Services Daemon to manage remote'
                               . ' authentication mechanisms'),
                'module' => 'users'
            },
           );
    }

    return \@files;
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

    # Create default rules and services
    # only if installing the first time
    unless ($version) {
        my $services = EBox::Global->modInstance('services');

        my $serviceName = 'samba';
        unless($services->serviceExists(name => $serviceName)) {
            $services->addMultipleService(
                'name' => $serviceName,
                'printableName' => 'Samba',
                'description' => __('Domain and File sharing protocols'),
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

sub _checkEnableIPs
{
    my ($self) = @_;
    my $network = $self->global()->modInstance('network');
    my @dhcpIfaces = ();
    my $noAddresses = 1;
    foreach my $iface (@{ $network->allIfaces() }) {
        my @addresses = @{ $network->ifaceAddresses($iface) };
        if (@addresses) {
            $noAddresses = 0;
            last;
        }
        if ($network->ifaceMethod($iface) eq 'dhcp') {
            push @dhcpIfaces, $iface;
        }
    }
    if ($noAddresses) {
        my $errMsg;
        if (@dhcpIfaces) {
            $errMsg = __x('Cannot enable Users and Computers module because your system does not have availalbe IPs. Since you have dhcp interfaces ({ifaces}) it is possible that you have not received leases. Saving changes if network module has just been configured or waiting for a lease can solve this situation',
                          ifaces => "@dhcpIfaces"
                         );
        } else {
            $errMsg = __x('Cannot enable Users and Computers module because your system does not have available IPs. {oh}Configuring network interfaces{ch} and saving changes can solve this situation',
                          oh => '<a href="/Network/Ifaces">',
                          ch => '</a>'
                          );
        }

        EBox::Exceptions::External->throw($errMsg);
    }
}

sub setupDNS
{
    my ($self) = @_;

    EBox::info("Setting up DNS");

    # Get the host domain
    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $ownDomain = $sysinfo->hostDomain();
    my $hostName = $sysinfo->hostName();

    # Create the domain in the DNS module if it does not exists
    my $dnsMod = EBox::Global->modInstance('dns');
    my $domainModel = $dnsMod->model('DomainTable');
    my $row = $domainModel->find(domain => $ownDomain);
    if (defined $row) {
        # Set the domain as managed and readonly
        $row->setReadOnly(1);
        $row->elementByName('managed')->setValue(1);
        $row->store();
    } else {
        $domainModel->addRow(domain => $ownDomain, managed => 1, readOnly => 1);
    }

    EBox::debug("Adding DNS records for kerberos");

    # Add the TXT record with the realm name
    my $txtRR = { name => '_kerberos',
                  data => $ownDomain,
                  readOnly => 1 };
    $dnsMod->addText($ownDomain, $txtRR);

    # Add the SRV records to the domain
    my $service = { service => 'kerberos',
                    protocol => 'tcp',
                    port => KERBEROS_PORT,
                    priority => 100,
                    weight => 100,
                    target_type => 'domainHost',
                    target => $hostName,
                    readOnly => 1 };
    $dnsMod->addService($ownDomain, $service);
    $service->{protocol} = 'udp';
    $dnsMod->addService($ownDomain, $service);

    ## TODO Check if the server is a master or slave and adjust the target
    ##      to the master server
    $service = { service => 'kerberos-master',
                 protocol => 'tcp',
                 port => KERBEROS_PORT,
                 priority => 100,
                 weight => 100,
                 target_type => 'domainHost',
                 target => $hostName,
                 readOnly => 1 };
    $dnsMod->addService($ownDomain, $service);
    $service->{protocol} = 'udp';
    $dnsMod->addService($ownDomain, $service);

    $service = { service => 'kpasswd',
                 protocol => 'tcp',
                 port => KPASSWD_PORT,
                 priority => 100,
                 weight => 100,
                 target_type => 'domainHost',
                 target => $hostName,
                 readOnly => 1 };
    $dnsMod->addService($ownDomain, $service);
    $service->{protocol} = 'udp';
    $dnsMod->addService($ownDomain, $service);
}

# Method: enableActions
#
#   Override EBox::Module::Service::enableActions
#
sub enableActions
{
    my ($self) = @_;

    $self->_setAppArmorProfiles();

    my $mode = $self->mode();
    $self->_setupForMode();
    if ($mode eq STANDALONE_MODE) {
        $self->_internalServerEnableActions();
    } elsif ($mode eq EXTERNAL_AD_MODE) {
        $self->_externalADEnableActions();
    } else {
        throw EBox::Exceptions::Internal("Unknown mode $mode");
    }
}

sub _internalServerEnableActions
{
    my ($self) = @_;

    $self->_checkEnableIPs();

    # Setup DNS
    $self->setupDNS();

    # Execute enable-module script
    $self->SUPER::enableActions();

    # mark webAdmin as changed to avoid problems with getpwent calls, it needs
    # to be restarted to be aware of the new nsswitch conf
    EBox::Global->modInstance('webadmin')->setAsChanged();
}

sub _externalADEnableActions
{
    my ($self) = @_;
    my $global = $self->global();
    # we need to restart network to force the regeneration of DNS resolvers
    $global->modInstance('network')->setAsChanged();
    # we need to webadmin to clear DNs cache daa
    $global->modInstance('webadmin')->setAsChanged();
}

sub enableService
{
    my ($self, $status) = @_;

    if ($status) {
        my $throwException = 1;
        if ($self->{restoringBackup}) {
            $throwException = 0;
        }
        $self->getProvision->checkEnvironment($throwException);
    }

    $self->SUPER::enableService($status);

    my $dns = EBox::Global->modInstance('dns');
    $dns->setAsChanged();
}

sub _startDaemon
{
    my ($self, $daemon, %params) = @_;

    $self->SUPER::_startDaemon($daemon, %params);

    my $services = $self->_services($daemon->{name});
    foreach my $service (@{$services}) {
        my $port = $service->{destinationPort};
        next unless $port;

        my $proto = $service->{protocol};
        next unless $proto;

        my $desc = $service->{description};
        if ($proto eq 'tcp/udp') {
            $self->_waitService('tcp', $port, $desc);
            $self->_waitService('udp', $port, $desc);
        } elsif (($proto eq 'tcp') or ($proto eq 'udp')) {
            $self->_waitService($proto, $port, $desc);
        }
    }
}

# Method: _waitService
#
#   This function will block until service is listening or timed
#   out (300 * 0.1 = 30 seconds)
#
sub _waitService
{
    my ($self, $proto, $port, $desc) = @_;

    my $maxTries = 300;
    my $sleepSeconds = 0.1;
    my $listening = 0;

    if (length ($desc)) {
        EBox::debug("Wait users task '$desc'");
    } else {
        EBox::debug("Wait unknown users task");
    }
    while (not $listening and $maxTries > 0) {
        my $sock = new IO::Socket::INET(PeerAddr => '127.0.0.1',
                                        PeerPort => $port,
                                        Proto    => $proto);
        if ($sock) {
            $listening = 1;
            last;
        }
        $maxTries--;
        Time::HiRes::sleep($sleepSeconds);
    }

    unless ($listening) {
        EBox::warn("Timeout reached while waiting for users service '$desc' ($proto)");
    }
}

sub _services
{
    my ($self) = @_;

    # TODO: separate this in different services?
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


# Generate, store in the given file and return a password
sub _genPassword
{
    my ($self, $file) = @_;

    my $pass = EBox::Util::Random::generate(20);
    my ($login,$password,$uid,$gid) = getpwnam('ebox');
    EBox::Module::Base::writeFile($file, $pass,
            { mode => '0600', uid => $uid, gid => $gid });

    return $pass;
}

# Method: wizardPages
#
#   Override EBox::Module::Base::wizardPages
#
sub wizardPages
{
    my ($self) = @_;
    return [{ page => '/Users/Wizard/Users', order => 300 }];
}

# Method: _regenConfig
#
#   Overrides <EBox::Module::Service::_regenConfig>
#
sub _regenConfig
{
    my $self = shift;

    return unless $self->configured();

    # Do provision first before adding schemas, overrides
    # default EBox::Module::LDAP behavior of adding schemas
    # first and then regenConfig when users already provisioned
    $self->EBox::Module::Service::_regenConfig(@_);
    $self->_performSetup();
}

# Method: _setConf
#
#       Override EBox::Module::Service::_setConf
#
#  Parameters:
#    noSlaveSetup - don't setup slaves in standalone serve mode
#
sub _setConf
{
    my ($self, $noSlaveSetup) = @_;
    $self->_setupForMode();

    # Setup kerberos config file
    # FIXME: This should go now inside external AD?
#    my $realm = $self->kerberosRealm();
#    my @params = ('realm' => $realm);
#    $self->writeConfFile(KRB5_CONF_FILE, 'users/krb5.conf.mas', \@params);

    if ($self->mode() eq EXTERNAL_AD_MODE) {
        $self->_setConfExternalAD();
    } else {
        $self->_setConfInternal($noSlaveSetup);
    }
}

sub _setConfExternalAD
{
    my ($self) = @_;

    # Install cron file to update the squid keytab in the case keys change
    $self->writeConfFile(CRONFILE_EXTERNAL_AD_MODE, "users/zentyal-users-external-ad.cron.mas", []);
    EBox::Sudo::root('chmod a+x ' . CRONFILE_EXTERNAL_AD_MODE);
}

sub _setConfInternal
{
    my ($self, $noSlaveSetup) = @_;

    return unless $self->configured() and $self->isEnabled();

    $self->writeSambaConfig();

    my $prov = $self->getProvision();
    if ((not $prov->isProvisioned()) or $self->get('need_reprovision')) {
        if (EBox::Global->modExists('openchange')) {
            my $openchangeMod = EBox::Global->modInstance('openchange');
            if ($openchangeMod->isProvisioned()) {
                # Set OpenChange as not provisioned.
                $openchangeMod->setProvisioned(0);
            }
        }
        if ($self->get('need_reprovision')) {
            $self->_cleanModulesForReprovision();
            # Current provision is not useful, change back status to not provisioned.
            $prov->setProvisioned(0);
            # The LDB connection needs to be reset so we stop using cached values.
            $self->ldb()->clearConn()
        }
        $prov->provision();
        $self->unset('need_reprovision');
    }

    $self->writeSambaConfig();

    my $ldap = $self->ldap;

    # Link kerberos to be system-wide after provision
    EBox::Sudo::root('ln -sf ' . KRB5_CONF_FILE . ' ' . SYSTEM_WIDE_KRB5_CONF_FILE);

    $self->_setupNSSPAM();

    # Slaves cron
    my @params;
    push(@params, 'slave_time' => EBox::Config::configkey('slave_time'));
    if ($self->master() eq 'cloud') {
        my $rs = new EBox::Global->modInstance('remoteservices');
        my $rest = $rs->REST();
        my $res = $rest->GET("/v1/users/realm/")->data();
        my $realm = $res->{realm};

        # Initial sync, set the realm (definitive) and upload current users
        if (not $realm) {
            $rest->PUT("/v1/users/realm/", query => { realm => $self->kerberosRealm() });

            # Send current users and groups
            $self->initialSlaveSync(new EBox::CloudSync::Slave(), 1);
        }

        push(@params, 'cloudsync_enabled' => 1);
    }

    # TODO: No users sync in 3.4, reenable in 4.0
    #$self->writeConfFile(CRONFILE, "users/zentyal-users.cron.mas", \@params);

    # Configure as slave if enabled
    $self->masterConf->setupSlave() unless ($noSlaveSetup);

    # commit slaves removal
    EBox::Users::Slave->commitRemovals($self->global());
}

sub _postServiceHook
{
    my ($self, $enabled) = @_;

    if ($enabled) {
        if ($self->mode() eq EXTERNAL_AD_MODE) {
            # Update services keytabs
            my $ldap = $self->ldap();
            my @principals = @{ $ldap->externalServicesPrincipals() };
            if (scalar @principals) {
                $ldap->initKeyTabs();
            }
        } else {
            EBox::Users::Provision::provisionGIDNumbersDefaultGroups();
        }
    }
}

# overriden to revoke slave removals
sub revokeConfig
{
   my ($self) = @_;
   $self->SUPER::revokeConfig();
   EBox::Users::Slave->revokeRemovals($self->global());
}

sub kerberosRealm
{
    my ($self) = @_;

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $realm = uc ($sysinfo->hostDomain());
    return $realm;
}

# Set up NSS PAM for LDB users
sub _setupNSSPAM
{
    my ($self) = @_;

    my @array = ();
    my $umask = EBox::Config::configkey('dir_umask');
    push (@array, 'umask' => $umask);

    $self->writeConfFile(AUTHCONFIGTMPL, 'users/acc-zentyal.mas',
                         \@array);

    my $PAMModule = $self->model('PAM');
    my $enablePAM = $PAMModule->enable_pamValue();
    $self->_setupSSSd($PAMModule->login_shellValue());

    my $cmd;
    if ($enablePAM) {
        $cmd = 'auth-client-config -a -p zentyal-krb';
    } else {
        $cmd = 'auth-client-config -a -p zentyal-nokrb';
    }
    EBox::Sudo::root($cmd);
}

# Set up SSS daemon
sub _setupSSSd
{
    my ($self, $defaultShell) = @_;

    my $sysinfo = $self->global()->modInstance('sysinfo');
    my @params = ('fqdn'   => $sysinfo->fqdn(),
                  'domain' => $sysinfo->hostDomain(),
                  'defaultShell' => $defaultShell,
                  'keyTab' => SECRETS_KEYTAB);

    # SSSd conf file must be owned by root and only rw by him
    $self->writeConfFile(SSSD_CONF_FILE, 'users/sssd.conf.mas',
                         \@params,
                         {'mode' => '0600', uid => 0, gid => 0});
}

# Method: editableMode
#
#       Check if users and groups can be edited.
#
#       They could not be edited ither mode is external-ad or the syncprovider
#       does not allows it
#
sub editableMode
{
    my ($self) = @_;
    if ($self->mode() ne STANDALONE_MODE) {
        return 0;
    }

    my $global = EBox::Global->modInstance('global');
    my @names = @{$global->modNames};

    my @modules;
    foreach my $name (@names) {
        my $mod = EBox::Global->modInstance($name);

        if ($mod->isa('EBox::Users::SyncProvider')) {
            return 0 unless ($mod->allowUserChanges());
        }
    }

    return 1;
}

# Method: _daemons
#
#       Override EBox::Module::Service::_daemons
#
sub _daemons
{
    my ($self) = @_;

    my $usingInternalServer = sub {
        return ($self->mode() eq STANDALONE_MODE);
    };

    return [
        {
            name => 'samba-ad-dc',
            precondition => $usingInternalServer
        },
        {
            name => 'sssd',
            precondition => $usingInternalServer
        },
    ];
}

# Method: _daemonsToDisable
#
# Overrides:
#
#   <EBox::Module::Service::_daemonsToDisable>
#
sub _daemonsToDisable
{
    return [
        { 'name' => 'smbd', 'type' => 'upstart' },
        { 'name' => 'nmbd', 'type' => 'upstart' },
    ];
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
    EBox::Sudo::root("setfacl -b " . SAMBA_PRIVILEGED_SOCKET);

    # User corner needs access to update the user password
    if (EBox::Global->modExists('usercorner')) {
        my $usercorner = EBox::Global->modInstance('usercorner');
        my $userCornerGroup = $usercorner->USERCORNER_GROUP();
        EBox::Sudo::root("setfacl -m \"g:$userCornerGroup:rx\" " . SAMBA_PRIVILEGED_SOCKET);
    }

    $self->SUPER::_startService(@_);
}

# Method: groupDn
#
#    Returns the dn for a given group. The group doesn't have to exist
#
#   Parameters:
#       group
#
#  Returns:
#     dn for the group
#
# FIXME: This should not be used anymore...
sub groupDn
{
    my ($self, $group) = @_;
    $group or throw EBox::Exceptions::MissingArgument('group');

    my $dn = "cn=$group," . EBox::Users::Group->defaultContainer()->dn();
    return $dn;
}

# Init a new user (home and permissions)
sub initUser
{
    my ($self, $user) = @_;

    my $mk_home = EBox::Config::configkey('mk_home');
    $mk_home = 'yes' unless $mk_home;
    if ($mk_home eq 'yes') {
        my $home = $user->home();
        if ($home and ($home ne '/dev/null') and (not -e $home)) {
            my $quser = shell_quote($user->name());
            my $qhome = shell_quote($home);
            my $group = DEFAULTGROUP;
            my @cmds;
            push (@cmds, "mkdir -p `dirname $qhome`");
            push (@cmds, "cp -dR --preserve=mode /etc/skel $qhome");
            push (@cmds, "chown -R $quser $qhome");
            push (@cmds, "chgrp -R '$group' $qhome");

            my $dir_umask = oct(EBox::Config::configkey('dir_umask'));
            my $perms = sprintf("%#o", 00777 &~ $dir_umask);
            push (@cmds, "chmod $perms $qhome");
            EBox::Sudo::root(@cmds);
        }
    }
}

# Reload nscd daemon if it's installed
sub reloadNSCD
{
    if (-f '/etc/init.d/nscd') {
        try {
            EBox::Sudo::root('service nscd force-reload');
        } catch {
        }
   }
}

# Method: containers
#
#   Returns an array containing all the containers. The array is ordered in a
#   hierarquical way. Parents before childs.
#
# Returns:
#
#   array ref - holding the containers. Each member is represented by a
#   EBox::Users::Container object
#
sub containers
{
    my ($self, $baseDN) = @_;

    return [] if (not $self->isEnabled());

    unless (defined $baseDN) {
        $baseDN = $self->ldap->dn();
    }

    my $objectClass = $self->{ouClass}->mainObjectClass();
    my $searchArgs = {
        base => $baseDN,
        filter => "objectclass=$objectClass",
        scope => 'one',
    };

    my $ous = [];
    my $result = $self->ldap->search($searchArgs);
    foreach my $entry ($result->entries()) {
        my $ou = EBox::Users::OU->new(entry => $entry);
        push (@{$ous}, $ou);
        my $nested = $self->ous($ou->dn());
        push (@{$ous}, @{$nested});
    }

    return $ous;
}

# Method: ous
#
#   Returns an array containing all the OUs. The array ir ordered in a
#   hierarquical way. Parents before childs.
#
# Returns:
#
#   array ref - holding the OUs. Each user is represented by a
#   EBox::Users::OU object
#
sub ous
{
    my ($self, $baseDN) = @_;

    return [] if (not $self->isEnabled());

    unless (defined $baseDN) {
        $baseDN = $self->ldap->dn();
    }

    my $objectClass = $self->{ouClass}->mainObjectClass();
    my $searchArgs = {
        base => $baseDN,
        filter => "objectclass=$objectClass",
        scope => 'one',
    };

    my $ous = [];
    my $result = $self->ldap->search($searchArgs);
    foreach my $entry ($result->entries()) {
        my $ou = EBox::Users::OU->new(entry => $entry);
        push (@{$ous}, $ou);
        my $nested = $self->ous($ou->dn());
        push (@{$ous}, @{$nested});
    }

    return $ous;
}

# Method: userByUID
#
# Return the instance of EBox::Users::User object which represents a given uid or undef if it's not found.
#
#  Parameters:
#      uid
#
sub userByUID
{
    my ($self, $uid) = @_;

    my $userClass = $self->userClass();
    my $objectClass = $userClass->mainObjectClass();
    my $uidTag = $userClass->uidTag();
    my $args = {
        base => $self->ldap->dn(),
        filter => "(&(objectclass=$objectClass)($uidTag=$uid))",
        scope => 'sub',
    };

    my $result = $self->ldap->search($args);
    my $count = $result->count();
    if ($count > 1) {
        throw EBox::Exceptions::Internal(
            __x('Found {count} results for \'{uid}\' user, expected only one.',
                count => $count,
                name  => $uid
            )
        );
    } elsif ($count == 0) {
        return undef;
    } else {
        return $self->entryModeledObject($result->entry(0));
    }
}

# Method: userExists
#
#  Returns:
#
#      bool - whether the user exists or not
#
sub userExists
{
    my ($self, $uid) = @_;
    my $user = $self->userByUID($uid);
    if (not $user) {
        return undef;
    }

    # FIXME
    # check if it is a reserved user
    my $samba = $self->global()->modInstance('samba');
    if (not $samba->isProvisioned()) {
        return OBJECT_EXISTS;
    }
    my $ldbUser = $samba->ldbObjectByObjectGUID($user->get('msdsObjectGUID'));
    if ($samba->hiddenSid($ldbUser)) {
        return OBJECT_EXISTS_AND_HIDDEN_SID;
    }

    return OBJECT_EXISTS;
}

# Method: users
#
#       Returns an array containing all the users (not system users)
#
# Parameters:
#       system - show system users also (default: false)
#
# Returns:
#
#       array ref - holding the users. Each user is represented by a
#       EBox::Users::User object
#
sub users
{
    my ($self, $system) = @_;

    return [] if (not $self->isEnabled());

    my $objectClass = $self->{userClass}->mainObjectClass();
    my %args = (
        base => $self->ldap->dn(),
        filter => "objectclass=$objectClass",
        scope => 'sub',
    );

    my $entries = $self->ldap->pagedSearch(\%args);

    my @users = ();
    foreach my $entry (@{ $entries })
    {
        my $user = $self->{userClass}->new(entry => $entry);
        # Include system users?
        next if (not $system and $user->isSystem());

        push (@users, $user);
    }

    # sort by name
    @users = sort {
            my $aValue = $a->name();
            my $bValue = $b->name();
            (lc $aValue cmp lc $bValue) or
                ($aValue cmp $bValue)
    } @users;

    return \@users;
}

# Method: realUsers
#
#       Returns an array containing all the non-internal users
#
# Returns:
#
#       array ref - holding the users. Each user is represented by a
#       EBox::Users::User object
#
sub realUsers
{
    my ($self) = @_;

    my @users = grep { not $_->isInternal() } @{$self->users()};

    return \@users;
}

# Method: realGroups
#
#       Returns an array containing all the non-internal groups
#
# Returns:
#
#       array ref - holding the groups. Each user is represented by a
#       EBox::Users::Group object
#
sub realGroups
{
    my ($self) = @_;

    my @groups = grep { not $_->isInternal() } @{$self->securityGroups()};

    return \@groups;
}

# Method: contactsByName
#
# Return a reference to a list of instances of EBox::Users::Contact objects which represents a given name.
#
#  Parameters:
#      name
#
sub contactsByName
{
    my ($self, $name) = @_;

    my $contactClass = $self->contactClass();
    my $objectClass = $contactClass->mainObjectClass();
    my $args = {
        base => $self->ldap->dn(),
        filter => "(&(objectclass=$objectClass)(cn=$name))",
        scope => 'sub',
    };

    my $result = $self->ldap->search($args);
    my $count = $result->count();
    return [] if ($count == 0);

    my @contacts = ();

    foreach my $entry (@{$result->entries}) {
        my $contact = $self->entryModeledObject($entry);
        push (@contacts, $contact) if ($contact);
    }

    return \@contacts;
}

# Method: contactExists
#
#  Returns:
#
#      bool - whether the contact exists or not
#
sub contactExists
{
    my ($self, $name) = @_;
    return undef unless ($self->contactsByName($name));
    return 1;
}

# Method: contacts
#
#       Returns an array containing all the contacts
#
# Returns:
#
#       array ref - holding the contacts. Each contact is represented by a
#       EBox::Users::Contact object
#
sub contacts
{
    my ($self) = @_;

    return [] if (not $self->isEnabled());

    my %args = (
        base => $self->ldap->dn(),
        filter => '(&(objectclass=inetOrgPerson)(!(objectclass=posixAccount)))',
        scope => 'sub',
    );

    my $result = $self->ldap->search(\%args);

    my @contacts = ();
    foreach my $entry ($result->entries) {
        my $contact = new EBox::Users::Contact(entry => $entry);

        push (@contacts, $contact);
    }

    # sort by name
    @contacts = sort {
        my $aValue = $a->fullname();
        my $bValue = $b->fullname();
        (lc $aValue cmp lc $bValue) or ($aValue cmp $bValue)
    } @contacts;

    return \@contacts;
}

# Method: groupByName
#
# Return the instance of EBox::Users::Group object which represents a give group name or undef if it's not found.
#
#  Parameters:
#      name
#
sub groupByName
{
    my ($self, $name) = @_;

    my $groupClass = $self->groupClass();
    my $objectClass = $groupClass->mainObjectClass();
    my $args = {
        base => $self->ldap->dn(),
        filter => "(&(objectclass=$objectClass)(cn=$name))",
        scope => 'sub',
    };

    my $result = $self->ldap->search($args);
    my $count = $result->count();
    if ($count > 1) {
        throw EBox::Exceptions::Internal(
            __x('Found {count} results for \'{name}\' group, expected only one.',
                count => $count,
                name  => $name
            )
        );
    } elsif ($count == 0) {
        return undef;
    } else {
        return $self->entryModeledObject($result->entry(0));
    }
}

# Method: groupExists
#
#  Returns:
#
#      bool - whether the group exists or not
#
sub groupExists
{
    my ($self, $name) = @_;
    my $group = $self->groupByName($name);
    if (not $group) {
        return undef;
    }

    # FIXME
    if ($self->global()->modExists('samba')) {
        # check if it is a reserved user
        my $samba = $self->global()->modInstance('samba');
        if (not $samba->isProvisioned()) {
            return OBJECT_EXISTS;
        }
        my $ldbGroup = $samba->ldbObjectByObjectGUID($group->get('msdsObjectGUID'));
        if ($samba->hiddenSid($ldbGroup)) {
            return OBJECT_EXISTS_AND_HIDDEN_SID;
        }
    }

    return OBJECT_EXISTS;
}

# Method: groups
#
#       Returns an array containing all the groups
#
#   Parameters:
#       system - show system groups (default: false)
#
# Returns:
#
#       array - holding the groups as EBox::Users::Group objects
#
sub groups
{
    my ($self, $system) = @_;

    return [] if (not $self->isEnabled());

    my $groupClass  = $self->groupClass();
    my $objectClass = $groupClass->mainObjectClass();
    my %args = (
        base => $self->ldap->dn(),
        filter => "objectclass=$objectClass",
        scope => 'sub',
    );

    my $result = $self->ldap->search(\%args);

    my @groups = ();
    foreach my $entry ($result->entries())  {
        my $group = $groupClass->new(entry => $entry);

        # Include system users?
        next if (not $system and $group->isSystem());

        push (@groups, $group);
    }
    # sort grups by name
    @groups = sort {
        my $aValue = $a->name();
        my $bValue = $b->name();
        (lc $aValue cmp lc $bValue) or
            ($aValue cmp $bValue)
    } @groups;

    return \@groups;
}

# Method: securityGroups
#
#       Returns an array containing all the security groups
#
#   Parameters:
#       system - show system groups (default: false)
#
# Returns:
#
#       array - holding the groups as EBox::Users::Group objects
#
sub securityGroups
{
    my ($self, $system) = @_;

    return [] if (not $self->isEnabled());

    my %args = (
        base => $self->ldap->dn(),
        filter => '(&(objectclass=zentyalDistributionGroup)(objectclass=posixGroup))',
        scope => 'sub',
    );

    my $result = $self->ldap->search(\%args);

    my @groups = ();
    foreach my $entry ($result->entries())
    {
        my $group = new EBox::Users::Group(entry => $entry);

        # Include system users?
        next if (not $system and $group->isSystem());

        push (@groups, $group);
    }
    # sort grups by name
    @groups = sort {
        my $aValue = $a->name();
        my $bValue = $b->name();
        (lc $aValue cmp lc $bValue) or
            ($aValue cmp $bValue)
    } @groups;

    return \@groups;
}

# Method: _modsLdapUserbase
#
# Returns modules implementing LDAP user base interface
#
# Parameters:
#   ignored_modules (Optional) - array ref to a list of module names to ignore
#
sub _modsLdapUserBase
{
    my ($self, $ignored_modules) = @_;

    my $global = EBox::Global->modInstance('global');
    my @names = @{$global->modNames};

    $ignored_modules or $ignored_modules = [];

    my @modules;
    foreach my $name (@names) {
        next if ($name eq any @{$ignored_modules});

        my $mod = EBox::Global->modInstance($name);

        if ($mod->isa('EBox::Module::LDAP')) {
            if ($name ne $self->name()) {
                $mod->configured() or
                    next;
            }
            push (@modules, $mod->_ldapModImplementation);
        }
    }

    return \@modules;
}

# Method: allSlaves
#
# Returns all slaves from LDAP Sync Provider
#
sub allSlaves
{
    my ($self) = @_;

    my $global = EBox::Global->modInstance('global');
    my @names = @{$global->modNames};

    my @modules;
    foreach my $name (@names) {
        my $mod = EBox::Global->modInstance($name);

        if ($mod->isa('EBox::Users::SyncProvider')) {
            push (@modules, @{$mod->slaves()});
        }
    }

    return \@modules;
}

# Method: notifyModsPreLdapUserBase
#
#   Notify all modules implementing LDAP user base interface about
#   a change in users or groups before it happen.
#
# Parameters:
#
#   signal - Signal name to notify the modules (addUser, delUser, modifyGroup, ...)
#   args - single value or array ref containing signal parameters
#   ignored_modules - array ref of modnames to ignore (won't be notified)
#
sub notifyModsPreLdapUserBase
{
    my ($self, $signal, $args, $ignored_modules) = @_;

    # convert signal to method name
    my $method = '_' . $signal;

    # convert args to array if it is a single value
    unless (ref ($args) eq 'ARRAY') {
        $args = [ $args ];
    }

    foreach my $mod (@{$self->_modsLdapUserBase($ignored_modules)}) {
        $mod->$method(@{$args});
    }
}

# Method: notifyModsLdapUserBase
#
#   Notify all modules implementing LDAP user base interface about
#   a change in users or groups
#
# Parameters:
#
#   signal - Signal name to notify the modules (addUser, delUser, modifyGroup, ...)
#   args - single value or array ref containing signal parameters
#   ignored_modules - array ref of modnames to ignore (won't be notified)
#   ignored_slaves -
#
sub notifyModsLdapUserBase
{
    my ($self, $signal, $args, $ignored_modules, $ignored_slaves) = @_;

    # convert signal to method name
    my $method = '_' . $signal;

    # convert args to array if it is a single value
    unless (ref($args) eq 'ARRAY') {
        $args = [ $args ];
    }

    my $defaultOU = $args->[0]->isInDefaultContainer();
    foreach my $mod (@{$self->_modsLdapUserBase($ignored_modules)}) {

        # Skip modules not supporting multiple OU if not default OU
        next unless ($mod->multipleOUSupport or $defaultOU);

        # TODO catch errors here? Not a good idea. The way to go is
        # to implement full transaction support and rollback if a notified
        # module throws an exception
        $mod->$method(@{$args});
    }

    # Save user corner operations for slave-sync daemon
    if ($self->isUserCorner()) {
        my $dir = '/var/lib/zentyal-usercorner/syncjournal/';
        mkdir ($dir) unless (-d $dir);

        my $time = time();
        my ($fh, $filename) = tempfile("$time-$signal-XXXX", DIR => $dir);
        EBox::Users::Slave->writeActionInfo($fh, $signal, $args);
        $fh->close();
        return;
    }

    # Notify slaves
    $ignored_slaves or $ignored_slaves = [];
    foreach my $slave (@{$self->allSlaves}) {
        my $name = $slave->name();
        next if ($name eq any @{$ignored_slaves});

        $slave->sync($signal, $args);
    }
}

# Method: initialSlaveSync
#
#   This method will send a sync signal for each
#   stored user and group.
#   It should be called on a slave registering
#
#   If sync parameter is given, the operation will
#   be sent instantly, if not, it will be saved for
#   slave-sync daemon
#
sub initialSlaveSync
{
    my ($self, $slave, $sync) = @_;

    foreach my $user (@{$self->users()}) {
        if ($sync) {
            $slave->sync('addUser', [ $user ]);
        } else {
            $slave->savePendingSync('addUser', [ $user ]);
        }
    }

    foreach my $group (@{$self->groups()}) {
        if ($sync) {
            $slave->sync('addGroup', [ $group ]);
            $slave->sync('modifyGroup', [ $group ]);
        } else {
            $slave->savePendingSync('addGroup', [ $group ]);
            $slave->savePendingSync('modifyGroup', [ $group ]);
        }
    }
}

# Method: isUserCorner
#
#  Returns:
#    true if we are running inside the user corner web server, false otherwise
sub isUserCorner
{
    my ($self) = @_;

    my $global = EBox::Global->modInstance('global');
    my $appName = $global->appName();
    if (defined $appName) {
        return ($appName eq 'usercorner');
    } else {
        return 0;
    }
}

# Method: defaultUserModels
#
#   Returns all the defaultUserModels from modules implementing
#   <EBox::LdapUserBase>
sub defaultUserModels
{
    my ($self) = @_;
    my @models;
    for my $module  (@{$self->_modsLdapUserBase()}) {
        my $model = $module->defaultUserModel();
        push (@models, $model) if (defined($model));
    }
    return \@models;
}

# Method: allUserAddOns
#
#       Returns all the mason components from those modules implementing
#       the function _userAddOns from EBox::LdapUserBase
#
# Parameters:
#
#       user - user object
#
# Returns:
#
#       array ref - holding all the components and parameters
#
sub allUserAddOns
{
    my ($self, $user) = @_;

    my $defaultOU = ($user->baseDn() eq $user->defaultContainer()->dn());

    my @modsFunc = @{$self->_modsLdapUserBase()};
    my @components;
    foreach my $mod (@modsFunc) {
        my $comp;
        if ($defaultOU or $mod->multipleOUSupport) {
            $comp = $mod->_userAddOns($user);
        } else {
            $comp  = $mod->noMultipleOUSupportComponent($user);
        }

        if ($comp) {
            $comp->{id} = ref $mod;
            $comp->{id} =~ s/:/_/g;
            push (@components, $comp);
        }
    }

    return \@components;
}

# Method: allGroupAddOns
#
#       Returns all the mason components from those modules implementing
#       the function _groupAddOns from EBox::LdapUserBase
#
# Parameters:
#
#       group  - group name
#
# Returns:
#
#       array ref - holding all the components and parameters
#
sub allGroupAddOns
{
    my ($self, $group) = @_;

    my $global = EBox::Global->modInstance('global');
    my @names = @{$global->modNames};

    my @modsFunc = @{$self->_modsLdapUserBase()};
    my @components;
    foreach my $mod (@modsFunc) {
        my $comp = $mod->_groupAddOns($group);
        if ($comp) {
            $comp->{id} = ref $mod;
            $comp->{id} =~ s/:/_/g;
            push (@components, $comp) if ($comp);
        }
    }

    return \@components;
}

# Method: allWarnings
#
#       Returns all the the warnings provided by the modules when a certain
#       user, group is going to be deleted. Function _delUserWarning or
#       _delGroupWarning is called in all module implementing them.
#
# Parameters:
#
#       object - Sort of object: 'user' or 'group'
#       name - name of the user or group
#
# Returns:
#
#       array ref - holding all the warnings
#
sub allWarnings
{
    my ($self, $object, $name) = @_;

    # TODO: Extend it for ous and contacts.
    return [] unless (($object eq 'user') or ($object eq 'group'));

    my @modsFunc = @{$self->_modsLdapUserBase()};
    my @allWarns;
    foreach my $mod (@modsFunc) {
        my $warn = undef;
        if ($object eq 'user') {
            $warn = $mod->_delUserWarning($name);
        } else {
            $warn = $mod->_delGroupWarning($name);
        }
        push (@allWarns, $warn) if ($warn);
    }

    return \@allWarns;
}

# Method: _supportActions
#
#       Overrides EBox::ServiceModule::ServiceInterface method.
#
sub _supportActions
{
    return undef;
}

# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
    my ($self, $root) = @_;

    my $separator = 'Office';
    my $order = 510;

    my $domainFolder = new EBox::Menu::Folder(name => 'Domain',
                                              text => __('Domain'),
                                              icon => 'domain',
                                              separator => 'Office',
                                              order => 535);

    $domainFolder->add(new EBox::Menu::Item(url   => 'Users/View/DomainSettings',
                                            text  => __('Settings'),
                                            order => 10));

    $domainFolder->add(new EBox::Menu::Item(url   => 'Users/View/GPOs',
                                            text  => __('Group Policy Objects'),
                                            order => 20));
    $domainFolder->add(new EBox::Menu::Item(url   => 'Users/Tree/GPOLinks',
                                            text  => __('Group Policy Links'),
                                            order => 30));

    $root->add($domainFolder);


    my $folder = new EBox::Menu::Folder('name' => 'Users',
                                        'icon' => 'users',
                                        'text' => $self->printableName(),
                                        'separator' => $separator,
                                        'order' => $order);
    if ($self->configured()) {
        $folder->add(new EBox::Menu::Item(
            'url'  => 'Users/Tree/Manage',
            'text' => __('Manage'), order => 10));
        $folder->add(new EBox::Menu::Item(
            'url'  => 'Users/Composite/UserTemplate',
            'text' => __('User Template'), order => 30));
# TODO: re-enable this in Zentyal 4.0 for Cloud Sync
#        if ($self->mode() eq STANDALONE_MODE) {
#            $folder->add(new EBox::Menu::Item(
#                'url'  => 'Users/Composite/Sync',
#                'text' => __('Synchronization'), order => 40));
#        }
        $folder->add(new EBox::Menu::Item(
            'url'  => 'Users/Composite/Settings',
            'text' => __('LDAP Settings'), order => 50));
    } else {
        $folder->add(new EBox::Menu::Item(
            'url'       => 'Users/View/Mode',
            'text'      => __('Configure mode'),
            'separator' => $separator,
            'order'     => 0));
    }
    $root->add($folder);
}

# EBox::UserCorner::Provider implementation

# Method: userMenu
#
sub userMenu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('url' => 'Users/View/Password',
                                    'text' => __('Password')));
}

# Method: syncJournalDir
#
#   Returns the path holding sync pending actions for
#   the given slave.
#   If the directory does not exists, it will be created;
#
sub syncJournalDir
{
    my ($self, $slave, $notCreate) = @_;

    my $dir = JOURNAL_DIR . $slave->name();
    my $journalsDir = JOURNAL_DIR;

    unless ($notCreate) {
        # Create if the dir does not exists
        unless (-d $dir) {
            EBox::Sudo::root(
                "mkdir -p $dir",
                "chown -R ebox:ebox $journalsDir",
                "chmod 0700 $journalsDir",
               );
        }
    }

    return $dir;
}

# LdapModule implementation
sub _ldapModImplementation
{
    return new EBox::LdapUserImplementation();
}

# SyncProvider implementation

# Method: slaves
#
#    Get the slaves for this server
#
# Returns:
#
#    array ref - containing the slaves for this server. Zentyal server slaves are
#                <EBox::UsersSync::Slave> instances and Zentyal Cloud slave is
#                a <EBox::CloudSync::Slave> instance.
#
sub slaves
{
    my ($self) = @_;

    my $model = $self->model('Slaves');

    my @slaves;
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $host = $row->valueByName('host');
        my $port = $row->valueByName('port');

        push (@slaves, new EBox::UsersSync::Slave($host, $port, $id));
    }

    my $g = EBox::Global->getInstance(1);
    my $u = $g->modInstance('users');
    if ($u->master() eq 'cloud') {
        push (@slaves, new EBox::CloudSync::Slave());
    }

    return \@slaves;
}

# Method: master
#
#   Return configured master as string, undef in none
#
#   Options: 'zentyal', 'cloud' or None
#
sub master
{
    my ($self) = @_;
    return $self->model('Master')->master();
}

# SyncProvider implementation
sub allowUserChanges
{
    my ($self) = @_;

    return (not $self->masterConf->isSlave());
}

# Master-Slave UsersSync object
sub masterConf
{
    my ($self) = @_;

    unless ($self->{ms}) {
        $self->{ms} = new EBox::UsersSync::Master();
    }
    return $self->{ms};
}

sub dumpConfig
{
    my ($self, $dir, %options) = @_;

    my $mode = $self->mode();
    File::Slurp::write_file($dir . '/' . BACKUP_MODE_FILE, $mode);
    if ($mode ne STANDALONE_MODE) {
        # the dump of the LDAP is only availabe in standalone server mode
        return;
    }

    my @cmds;

    my $mirror = EBox::Config::tmp() . "/samba.backup";
    my $privateDir = PRIVATE_DIR;
    if (EBox::Sudo::fileTest('-d', $privateDir)) {
        # Remove previous backup files
        my $ldbBakFiles = EBox::Sudo::root("find $privateDir -name '*.ldb.bak'");
        my $tdbBakFiles = EBox::Sudo::root("find $privateDir -name '*.tdb.bak'");
        foreach my $bakFile ((@{$ldbBakFiles}, @{$tdbBakFiles})) {
            chomp ($bakFile);
            push (@cmds, "rm '$bakFile'");
        }

        # Backup private. TDB and LDB files must be backed up using tdbbackup
        my $ldbFiles = EBox::Sudo::root("find $privateDir -name '*.ldb'");
        my $tdbFiles = EBox::Sudo::root("find $privateDir -name '*.tdb'");
        foreach my $dbFile ((@{$ldbFiles}, @{$tdbFiles})) {
            chomp ($dbFile);
            push (@cmds, "tdbbackup '$dbFile'");
            # Preserve file permissions
            my $st = EBox::Sudo::stat($dbFile);
            my $uid = $st->uid();
            my $gid = $st->gid();
            my $mode = sprintf ("%04o", $st->mode() & 07777);
            push (@cmds, "chown $uid:$gid $dbFile.bak");
            push (@cmds, "chmod $mode $dbFile.bak");
        }

        push (@cmds, "rm -rf $mirror");
        push (@cmds, "mkdir -p $mirror/private");
        push (@cmds, "rsync -HAXavz $privateDir/ " .
                     "--exclude=*.tdb --exclude=*.ldb " .
                     "--exclude=ldap_priv --exclude=smbd.tmp " .
                     "--exclude=ldapi $mirror/private");
        push (@cmds, "tar pcjf $dir/private.tar.bz2 --hard-dereference -C $mirror private");
    }

    # Backup sysvol
    my $sysvolDir = SYSVOL_DIR;
    if (EBox::Sudo::fileTest('-d', $sysvolDir)) {
        push (@cmds, "rm -rf $mirror");
        push (@cmds, "mkdir -p $mirror/sysvol");
        push (@cmds, "rsync -HAXavz $sysvolDir/ $mirror/sysvol");
        push (@cmds, "tar pcjf $dir/sysvol.tar.bz2 --hard-dereference -C $mirror sysvol");
    }

    try {
        EBox::Sudo::root(@cmds);
    } catch ($e) {
        $e->throw();
    }

    # Backup admin password
    unless ($options{bug}) {
        my $pwdFile = EBox::Config::conf() . 'samba.passwd';
        # Additional domain controllers does not have stashed pwd
        if (EBox::Sudo::fileTest('-f', $pwdFile)) {
            EBox::Sudo::root("cp '$pwdFile' $dir");
        }
    }
}

sub _usersInEtcPasswd
{
    my ($self) = @_;
    my @users;

    my @lines = File::Slurp::read_file('/etc/passwd');
    foreach my $line (@lines) {
        my ($user) = split ':', $line, 2;
        push @users, $user;
    }

    return \@users;
}

sub restoreDependencies
{
    my ($self) = @_;
    if ($self->mode() eq STANDALONE_MODE) {
            return ['dns'];
    }
    return [];
}

# Method: restoreBackupPreCheck
#
# Check that the backup to be restored mode is compatible.
# Also, in case we are using standalone mode, checks if we have clonflicts between
# users in the LDAP data to be loaded and the users in /etc/passwd
sub restoreBackupPreCheck
{
    my ($self, $dir) = @_;
    my $mode = $self->mode();
    my $backupModeFile = $dir . '/' . BACKUP_MODE_FILE;
    my $backupMode;
    if (-r $backupModeFile) {
        $backupMode =  File::Slurp::read_file($backupModeFile);
    } else {
        # standalone mode by default
        $backupMode = STANDALONE_MODE;
    }


    if ($mode ne $backupMode) {
        my $modeModel = $self->model('Mode');
        throw EBox::Exceptions::External(
            __x('Cannot restore users module bacuse is running in mode {mode} and the backup was made in mode {bpMode}',
                mode => $modeModel->modePrintableName($mode),
                bpMode => $modeModel->modePrintableName($backupMode),
               )
           );
    }

    if ($mode ne STANDALONE_MODE) {
        # nothing more to check
        return;
    }

    my %etcPasswdUsers = map { $_ => 1 } @{ $self->_usersInEtcPasswd() };

    my @usersToRestore = @{ $self->ldap->usersInBackup($dir) };
    foreach my $user (@usersToRestore) {
        if (exists $etcPasswdUsers{$user}) {
            throw EBox::Exceptions::External(__x('Cannot restore because LDAP user {user} already exists as /etc/passwd user. Delete or rename this user and try again', user => $user));
        }
    }
}

sub restoreConfig
{
    my ($self, $dir, $ignoreUserInitialization) = @_;
    my $mode = $self->mode();

    File::Slurp::write_file($dir . '/' . BACKUP_MODE_FILE, $mode);
    if ($mode ne STANDALONE_MODE) {
        # only standalone mode needs to do this operations to restore the LDAP
        # directory
        return;
    }

    my $modeDC = $self->dcMode();
    unless ($modeDC eq EBox::Users::Model::DomainSettings::MODE_DC()) {
        # Restoring an ADC will corrupt entire domain as sync data
        # get out of sync.
        EBox::info(__("Restore is only possible if the server is the unique " .
                      "domain controller of the forest"));
        $self->getProvision->setProvisioned(0);
        return;
    }

    $self->stopService();

    # Remove private and sysvol
    my $privateDir = PRIVATE_DIR;
    my $sysvolDir = SYSVOL_DIR;
    EBox::Sudo::root("rm -rf $privateDir $sysvolDir");

    # Unpack sysvol and private
    my %dest = ( sysvol => $sysvolDir, private => $privateDir );
    foreach my $archive (keys %dest) {
        if (EBox::Sudo::fileTest('-f', "$dir/$archive.tar.bz2")) {
            my $destdir = dirname($dest{$archive});
            EBox::Sudo::root("tar jxfp $dir/$archive.tar.bz2 -C $destdir");
        }
    }

    # Rename ldb files
    my $ldbBakFiles = EBox::Sudo::root("find $privateDir -name '*.ldb.bak'");
    my $tdbBakFiles = EBox::Sudo::root("find $privateDir -name '*.tdb.bak'");
    foreach my $bakFile ((@{$ldbBakFiles}, @{$tdbBakFiles})) {
        chomp $bakFile;
        my $destFile = $bakFile;
        $destFile =~ s/\.bak$//;
        EBox::Sudo::root("mv '$bakFile' '$destFile'");
    }
    # Hard-link DomainDnsZones and ForestDnsZones partitions
    EBox::Sudo::root("rm -f $privateDir/dns/sam.ldb.d/DC*FORESTDNSZONES*");
    EBox::Sudo::root("rm -f $privateDir/dns/sam.ldb.d/DC*DOMAINDNSZONES*");
    EBox::Sudo::root("rm -f $privateDir/dns/sam.ldb.d/metadata.tdb");
    EBox::Sudo::root("ln $privateDir/sam.ldb.d/DC*FORESTDNSZONES* $privateDir/dns/sam.ldb.d/");
    EBox::Sudo::root("ln $privateDir/sam.ldb.d/DC*DOMAINDNSZONES* $privateDir/dns/sam.ldb.d/");
    EBox::Sudo::root("ln $privateDir/sam.ldb.d/metadata.tdb $privateDir/dns/sam.ldb.d/");
    EBox::Sudo::root("chown root:bind $privateDir/dns/*.ldb");
    EBox::Sudo::root("chmod 660 $privateDir/dns/*.ldb");

    # Restore stashed password
    if (EBox::Sudo::fileTest('-f', "$dir/samba.passwd")) {
        EBox::Sudo::root("cp $dir/samba.passwd " . EBox::Config::conf());
        EBox::Sudo::root("chmod 0600 $dir/samba.passwd");
    }

    # Set provisioned flag
    $self->getProvision->setProvisioned(1);

    $self->restartService();

    $self->getProvision()->resetSysvolACL();

    return if $ignoreUserInitialization;

    for my $user (@{$self->users()}) {

        # Init local users
        $self->initUser($user);

        # Notify modules except samba because its users will be
        # restored from its own LDB backup
        $self->notifyModsLdapUserBase('addUser', $user, ['samba']);
    }
}

sub _removePasswds
{
  my ($self, $file) = @_;

  my $anyPasswdAttr = any(qw(
              userPassword
              sambaLMPassword
              sambaNTPassword
              )
          );
  my $passwordSubstitution = "password";

  my $FH_IN;
  open $FH_IN, "<$file" or
      throw EBox::Exceptions::Internal ("Cannot open $file: $!");

  my ($FH_OUT, $tmpFile) = tempfile(DIR => EBox::Config::tmp());

  foreach my $line (<$FH_IN>) {
      my ($attr, $value) = split ':', $line;
      if ($attr eq $anyPasswdAttr) {
          $line = $attr . ': ' . $passwordSubstitution . "\n";
      }

      print $FH_OUT $line;
  }

  close $FH_IN  or
      throw EBox::Exceptions::Internal ("Cannot close $file: $!");
  close $FH_OUT or
      throw EBox::Exceptions::Internal ("Cannot close $tmpFile: $!");

  File::Copy::move($tmpFile, $file);
  unlink $tmpFile;
}

sub listSchemas
{
    my ($self, $ldap) = @_;

    my %args = (
        'base' => 'cn=schema,cn=config',
        'scope' => 'one',
        'filter' => "(objectClass=olcSchemaConfig)"
    );
    my $result = $ldap->search(%args);

    my @schemas = map { $_->get_value('cn') } $result->entries();
    return \@schemas;
}

sub mode
{
    my ($self) = @_;
    my $mode = $self->model('Mode')->value('mode');
    if (not $mode) {
        return STANDALONE_MODE;
    }
    return $mode;
}

# Method: dcMode
#
#   Returns the configured server mode
#
sub dcMode
{
    my ($self) = @_;

    my $model = $self->model('DomainSettings');
    return $model->modeValue();
}


# Method: newLDAP
#
#  Return a new LDAP object instance of the class requiered by the active mode
#
sub newLDAP
{
    my ($self) = @_;
    my $mode = $self->mode();
    if ($mode eq EXTERNAL_AD_MODE) {
        return EBox::LDAP::ExternalAD->instance(
            @{ $self->model('Mode')->adModeOptions() }
           );
    }

    return  EBox::Ldap->instance();
}

# common check for user names and group names
sub checkNameLimitations
{
    my ($name) = @_;

    # combination of unix limitations + windows limitation characters are
    # limited to unix portable file character + space for windows compability
    # slash not valid as first character (unix limitation)
    # see http://technet.microsoft.com/en-us/library/cc776019%28WS.10%29.aspx
    if ($name =~ /^[a-zA-Z0-9\._-][a-zA-Z0-9\._[:space:]-]*$/) {
         return 1;
     } else {
         return undef;
     }
}

# Method: checkCnLimitations
#
#   Return whether the given string is valid for its usage as a cn field.
#
# Parameters:
#
#   string - The string to check.
#
sub checkCnLimitations
{
    my ($self, $string) = @_;

    if ($string =~ /^([a-zA-Z\d\s_-]+\.)*[a-zA-Z\d\s_-]+$/) {
        return 1;
    } else {
        return undef;
    }
}

#  Nethod: newUserUidNumber
#
#  return the uid for a new user
#
#   Parameters:
#     system - true if we want the uid for a system user, defualt false
#
sub newUserUidNumber
{
    my ($self, $system) = @_;

    return EBox::Users::User->_newUserUidNumber($system);
}

######################################
##  SysInfo observer implementation ##
######################################

# Method: hostDomainChanged
#
#   This method disallow the change of the host domain if the module is
#   configured (implies that the kerberos realm has been initialized)
#
sub hostDomainChanged
{
    my ($self, $oldDomainName, $newDomainName) = @_;

    if ($self->configured()) {
        $self->set('need_reprovision', 1);
        $self->setAsChanged(1); # for compability with machines with phantom
                                # need_reprovision in read-only tree
        EBox::Global->modInstance('webadmin')->setAsChanged();
    }
}

# Method: hostDomainChangedDone
#
#   This method updates the base DN for LDAP if the module has not
#   been configured yet
#
sub hostDomainChangedDone
{
    my ($self, $oldDomainName, $newDomainName) = @_;

    unless ($self->configured()) {
        my $mode = $self->model('Mode');
        my $newDN = $mode->getDnFromDomainName($newDomainName);
        $mode->setValue('dn', $newDN);
    }
}

# Method: reprovision
#
#   Destroys all LDAP/Kerberos configuration and creates a new
#   empty one. Useful after a host/domain change.
#
sub reprovision
{
    my ($self) = @_;

    return unless $self->configured();
    EBox::info("Reprovisioning LDAP");

    my @removeHomeCmds;
    foreach my $home (map { $_->home() } @{$self->users()}) {
        push (@removeHomeCmds, "rm -rf $home");
    }
    EBox::Sudo::root(@removeHomeCmds);

    $self->_manageService('stop');
    EBox::Sudo::root('rm -rf /var/lib/ldap/*');
    $self->_manageService('start');

    $self->enableActions();

    # LDAP module has lost its schemas and LDAP config after the reprovision
    my $global = $self->global();
    my @mods = @{ $global->sortModulesByDependencies($global->modInstances(), 'depends' ) };
    foreach my $mod (@mods) {
        if (not $mod->isa('EBox::Module::LDAP')) {
            next;
        } elsif ($mod->name() eq $self->name()) {
            # dont reconfigure itself
            next;
        } elsif (not $mod->configured()) {
            next;
        }
        $mod->reprovisionLDAP();
    }
}

sub reprovisionLDAP
{
    throw EBox::Exceptions::Internal("This method should not be called in user module");
}

# Implement EBox::SyncFolders::Provider interface
sub syncFolders
{
    my ($self) = @_;

    my @folders;

    if ($self->recoveryEnabled()) {
        push (@folders, new EBox::SyncFolders::Folder('/home', 'recovery'));
    }

    return \@folders;
}

sub recoveryDomainName
{
    return __('Users data');
}

# Overrides:
#   EBox::Report::DiskUsageProvider::_facilitiesForDiskUsage
sub _facilitiesForDiskUsage
{
    my ($self) = @_;

    my $usersPrintableName  = __(q{Users data});
    my $usersPath           = '/home';

    return {
        $usersPrintableName   => [ $usersPath ],
    };
}

# Method: entryModeledObject
#
#   Return the Perl Object that handles the given LDAP entry.
#
#   Throw EBox::Exceptions::Internal on error.
#
# Parameters:
#
#   entry - A Net::LDAP::Entry object.
#
sub entryModeledObject
{
    my ($self, $entry) = @_;

    my $anyObjectClasses = any(@{[$entry->get_value('objectClass')]});
    # IMPORTANT: The order matters, a contactClass would match users too, so we must check first if it's a user.
    foreach my $type ( qw(ouClass userClass contactClass groupClass containerClass)) {
        my $class = $self->$type();
        # containerClass may not exist.
        next unless ($class);
        my $mainLDAPClass = $class->mainObjectClass();
        if ((defined $mainLDAPClass) and ($mainLDAPClass eq $anyObjectClasses)) {
            return $class->new(entry => $entry);
        }
    }

    my $ldap = $self->ldap();
    if ($entry->dn() eq $ldap->dn()) {
        return $self->defaultNamingContext();
    }

    EBox::debug("Ignored unknown perl object for DN: " . $entry->dn());
    return undef;
}

# Method: relativeDN
#
#   Return the given dn without the naming Context part.
#
sub relativeDN
{
    my ($self, $dn) = @_;

    throw EBox::Exceptions::MissingArgument("dn") unless ($dn);

    my $baseDN = $self->ldap()->dn();

    return '' if ($dn eq $baseDN);

    if (not $dn =~ s/,$baseDN$//) {
        throw EBox::Exceptions::Internal("$dn is not contained in $baseDN");
    }

    return $dn;
}

# Method: objectFromDN
#
#   Return the perl object modeling the given dn or undef if not found.
#
# Parameters:
#
#   dn - An LDAP DN string identifying the object to retrieve.
#
sub objectFromDN
{
    my ($self, $dn) = @_;
    my $ldap = $self->ldap();
    if ($dn eq $ldap->dn()) {
        return $self->defaultNamingContext();
    }

    my $baseObject = new EBox::Users::LdapObject(dn => $dn);

    if ($baseObject->exists()) {
        return $self->entryModeledObject($baseObject->_entry());
    } else {
        return undef;
    }
}

# Method: defaultNamingContext
#
#   Return the Perl Object that holds the default Naming Context for this LDAP server.
#
#
sub defaultNamingContext
{
    my ($self) = @_;

    my $ldap = $self->ldap;
    return new EBox::Users::NamingContext(dn => $ldap->dn());
}

sub ousToHide
{
    my ($self) = @_;

    my @ous;

    foreach my $mod (@{EBox::Global->modInstancesOfType('EBox::Module::LDAP')}) {
        push (@ous, @{$mod->_ldapModImplementation()->hiddenOUs()});
    }

    return \@ous;
}

# Method: checkMailNotInUse
#
#   check if a mail address is not used by the system and throw exception if it
#   is already used
#
#   If mail module is installed its checkMailNotInUse method should be called
#   instead this one
sub checkMailNotInUse
{
    my ($self, $addr) = @_;
    my $usersMod = $self->global()->modInstance('users');
    my %searchParams = (
        base => $usersMod->ldap()->dn(),
        filter => "&(|(objectclass=person)(objectclass=couriermailalias)(objectclass=zentyalDistributionGroup))(|(otherMailbox=$addr)(mail=$addr))",
        scope => 'sub'
    );

    my $result = $self->{'ldap'}->search(\%searchParams);
    if ($result->count() > 0) {
        my $entry = $result->entry(0);
        my $modeledObject = $usersMod->entryModeledObject($entry);
        my $type = $modeledObject ? $modeledObject->printableType() : $entry->get_value('objectClass');
        my $name;
        if ($type eq 'CourierMailAlias') {
            $type = __('alias');
            $name = $entry->get_value('mail');
        } else {
            $name = $modeledObject ? $modeledObject->name() : $entry->dn();
        }

        EBox::Exceptions::External->throw(__x('Address {addr} is already in use by the {type} {name}',
                                              addr => $addr,
                                              type => $type,
                                              name => $name,
                                        ),
                                    );
    }
}

sub getProvision
{
    my ($self) = @_;

    unless (defined $self->{provision}) {
        $self->{provision} = new EBox::Users::Provision();
    }
    return $self->{provision};
}

sub isProvisioned
{
    my ($self) = @_;

    return $self->getProvision->isProvisioned();
}

# Method: domainControllers
#
#   Query the domain controllers by searching in 'Domain Controllers' OU
#
# Returns:
#
#   Array reference containing instances of EBox::Users::Computer class
#
sub domainControllers
{
    my ($self) = @_;

    return [] unless $self->isProvisioned();

    my $sort = new Net::LDAP::Control::Sort(order => 'name');
    my $ldb = $self->ldb();
    my $baseDN = $ldb->dn();
    my $args = {
        base => "OU=Domain Controllers,$baseDN",
        filter => 'objectClass=computer',
        scope => 'sub',
        control => [ $sort ],
    };

    my $result = $ldb->search($args);

    my @computers;
    foreach my $entry ($result->entries()) {
        my $computer = new EBox::Users::Computer(entry => $entry);
        next unless $computer->exists();
        push (@computers, $computer);
    }

    return \@computers;
}

# Method: computers
#
#   Query the computers joined to the domain by searching in the computers
#   container
#
# Returns:
#
#   Array reference containing instances of EBox::Users::Computer class
#
sub computers
{
    my ($self) = @_;

    return [] unless $self->isProvisioned();

    my $sort = new Net::LDAP::Control::Sort(order => 'name');
    my $ldb = $self->ldb();
    my $baseDN = $ldb->dn();
    my $args = {
        base => "CN=Computers,$baseDN",,
        filter => 'objectClass=computer',
        scope => 'sub',
        control => [ $sort ],
    };

    my $result = $self->ldb->search($args);

    my @computers;
    foreach my $entry ($result->entries()) {
        my $computer = new EBox::Users::Computer(entry => $entry);
        next unless $computer->exists();
        push (@computers, $computer);
    }

    return \@computers;
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
    $hostName = substr($hostName, 0, 15);

    return $hostName;
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
    my $value = substr($parts[0], 0, 15);
    $value = 'ZENTYAL-DOMAIN' unless defined $value;

    return uc($value);
}

# Method: defaultDescription
#
#   Generates the default server string
#
sub defaultDescription
{
    my $prefix = EBox::Config::configkey('custom_prefix');
    $prefix = 'zentyal' unless $prefix;

    return ucfirst($prefix) . ' Server';
}

sub writeSambaConfig
{
    my ($self) = @_;

    my $netbiosName = $self->netbiosName();
    my $realmName   = EBox::Global->modInstance('users')->kerberosRealm();

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $hostDomain = $sysinfo->hostDomain();

    my @array = ();
    push (@array, 'workgroup'   => $self->workgroup());
    push (@array, 'netbiosName' => $netbiosName);
    push (@array, 'description' => $self->description());
    push (@array, 'mode'        => 'dc');
    push (@array, 'realm'       => $realmName);
    push (@array, 'domain'      => $hostDomain);
    push (@array, 'roamingProfiles' => $self->roamingProfiles());
    push (@array, 'profilesPath' => PROFILES_DIR);
    push (@array, 'sysvolPath'  => SYSVOL_DIR);

    my $samba = $self->global()->modInstance('samba');
    if ($samba) {
        push (@array, 'shares' => 1);
        $samba->writeSambaConfig();
    }

    my $openchange = $self->global()->modInstance('openchange');
    if ($openchange and $openchange->isEnabled() and $openchange->isProvisioned()) {
        push (@array, 'openchange' => 1);
        $openchange->writeSambaConfig();
    }

    $self->writeConfFile(SAMBACONFFILE, 'users/smb.conf.mas', \@array,
                         { 'uid' => 'root', 'gid' => 'root', mode => '644' });
}

# Method: netbiosName
#
#   Returns the configured netbios name
#
sub netbiosName
{
    my ($self) = @_;

    my $model = $self->model('DomainSettings');
    return $model->netbiosNameValue();
}

# Method: workgroup
#
#   Returns the configured workgroup name
#
sub workgroup
{
    my ($self) = @_;

    my $model = $self->model('DomainSettings');
    return $model->workgroupValue();
}

# Method: description
#
#   Returns the configured description string
#
sub description
{
    my ($self) = @_;

    my $model = $self->model('DomainSettings');
    return $model->descriptionValue();
}

# Method: roamingProfiles
#
#   Returns if roaming profiles are enabled
#
sub roamingProfiles
{
    my ($self) = @_;

    my $model = $self->model('DomainSettings');
    return $model->roamingValue();
}

# Method: drive
#
#   Returns the configured drive letter
#
sub drive
{
    my ($self) = @_;

    my $model = $self->model('DomainSettings');
    return $model->driveValue();
}

# Method: administratorDN
#
#
# Returns:
#
#     String - the DN for the administrator or undef if it does not exist
#
sub administratorDN
{
    my ($self) = @_;

    my $ldb = $self->ldb();
    my $domainAdminSID = $ldb->domainSID() . '-500';

    my $result = $ldb->search({ base   => $self->userClass()->defaultContainer()->dn(),
                                filter => "objectSid=$domainAdminSID",
                                scope  => 'one',
                                attrs  => ['dn']});
    my @entries = $result->entries();
    my $dn;
    if (scalar(@entries) > 0) {
        $dn = $entries[0]->dn();
    }
    return $dn;
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

# Method: dMD
#
#   Return the Perl Object that holds the Directory Management Domain for this LDB server.
#
sub dMD
{
    my ($self) = @_;

    my $dn = "CN=Schema,CN=Configuration," . $self->ldb()->dn();
    return new EBox::Users::DMD(dn => $dn);
}

# Method: gpos
#
#   Returns the Domain GPOs
#
# Returns:
#
#   Array ref containing instances of EBox::Users::GPO
#
sub gpos
{
    my ($self) = @_;

    my $gpos = [];
    my $defaultNC = $self->ldb->dn();
    my $params = {
        base => "CN=Policies,CN=System,$defaultNC",
        scope => 'one',
        filter => '(objectClass=GroupPolicyContainer)',
        attrs => ['*']
    };
    my $result = $self->ldb->search($params);
    foreach my $entry ($result->entries()) {
        push (@{$gpos}, new EBox::Users::GPO(entry => $entry));
    }

    return $gpos;
}


sub _cleanModulesForReprovision
{
    my ($self) = @_;

    foreach my $mod (@{$self->global()->modInstancesOfType('EBox::Module::LDAP')}) {
        my $state = $mod->get_state();
        delete $state->{'_schemasAdded'};
        delete $state->{'_ldapSetup'};
        $mod->set_state($state);
        $mod->setAsChanged(1);
    }
}

1;
