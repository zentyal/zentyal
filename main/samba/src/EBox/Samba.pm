# Copyright (C) 2005-2007 Warp Networks S.L.
# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::Samba;

use base qw(EBox::Module::Service
            EBox::FirewallObserver
            EBox::SysInfo::Observer
            EBox::LdapModule
            EBox::LogObserver
            EBox::SyncFolders::Provider);

use EBox::Config;
use EBox::Exceptions::Internal;
use EBox::Exceptions::InvalidType;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::UnwillingToPerform;
use EBox::Gettext;
use EBox::Global;
use EBox::LDB;
use EBox::Menu::Item;
use EBox::Samba::BuiltinDomain;
use EBox::Samba::Computer;
use EBox::Samba::Contact;
use EBox::Samba::Container;
use EBox::Samba::GPO;
use EBox::Samba::Group;
use EBox::Samba::LdbObject;
use EBox::Samba::Model::GeneralSettings;
use EBox::Samba::NamingContext;
use EBox::Samba::OU;
use EBox::Samba::Provision;
use EBox::Samba::SecurityPrincipal;
use EBox::Samba::SmbClient;
use EBox::Samba::User;
use EBox::SambaLdapUser;
use EBox::SambaLogHelper;
use EBox::Service;
use EBox::Sudo;
use EBox::SyncFolders::Folder;
use EBox::Users;
use EBox::Users::User;
use EBox::Users::Group;
use EBox::Util::Random qw( generate );

use TryCatch::Lite;
use File::Basename;
use File::Slurp;
use File::Temp qw( tempfile tempdir );
use JSON::XS;
use Net::LDAP::Control::Sort;
use Net::LDAP::Util qw(ldap_explode_dn);
use Net::Ping;
use Perl6::Junction qw( any );
use Samba::Security::AccessControlEntry;
use Samba::Security::Descriptor qw(
    DOMAIN_RID_ADMINISTRATOR
    SEC_ACE_FLAG_CONTAINER_INHERIT
    SEC_ACE_FLAG_OBJECT_INHERIT
    SEC_ACE_TYPE_ACCESS_ALLOWED
    SEC_DESC_DACL_AUTO_INHERITED
    SEC_DESC_DACL_PROTECTED
    SEC_DESC_SACL_AUTO_INHERITED
    SEC_FILE_EXECUTE
    SEC_RIGHTS_FILE_ALL
    SEC_RIGHTS_FILE_READ
    SEC_RIGHTS_FILE_WRITE
    SEC_STD_ALL
    SEC_STD_DELETE
    SECINFO_DACL
    SECINFO_GROUP
    SECINFO_OWNER
    SECINFO_PROTECTED_DACL
    SEC_STD_WRITE_OWNER
    SEC_STD_READ_CONTROL
    SEC_STD_WRITE_DAC
    SEC_FILE_READ_ATTRIBUTE
);
use Samba::Smb qw(
    FILE_ATTRIBUTE_NORMAL
    FILE_ATTRIBUTE_ARCHIVE
    FILE_ATTRIBUTE_DIRECTORY
    FILE_ATTRIBUTE_HIDDEN
    FILE_ATTRIBUTE_READONLY
    FILE_ATTRIBUTE_SYSTEM
);
use String::ShellQuote 'shell_quote';
use Time::HiRes;
use IO::Socket::INET;

use constant SAMBA_DIR            => '/home/samba/';
use constant SAMBATOOL            => '/usr/bin/samba-tool';
use constant SAMBACONFFILE        => '/etc/samba/smb.conf';
use constant PRIVATE_DIR          => '/opt/samba4/private/';
use constant SAMBA_DNS_ZONE       => PRIVATE_DIR . 'named.conf';
use constant SAMBA_DNS_POLICY     => PRIVATE_DIR . 'named.conf.update';
use constant SAMBA_DNS_KEYTAB     => PRIVATE_DIR . 'dns.keytab';
use constant SECRETS_KEYTAB       => PRIVATE_DIR . 'secrets.keytab';
use constant SAM_DB               => PRIVATE_DIR . 'sam.ldb';
use constant SAMBA_PRIVILEGED_SOCKET => PRIVATE_DIR . '/ldap_priv';
use constant FSTAB_FILE           => '/etc/fstab';
use constant SYSVOL_DIR           => '/opt/samba4/var/locks/sysvol';
use constant SHARES_DIR           => SAMBA_DIR . 'shares';
use constant PROFILES_DIR         => SAMBA_DIR . 'profiles';
use constant ANTIVIRUS_CONF       => '/var/lib/zentyal/conf/samba-antivirus.conf';
use constant GUEST_DEFAULT_USER   => 'nobody';
use constant SAMBA_DNS_UPDATE_LIST => PRIVATE_DIR . 'dns_update_list';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(
        name => 'samba',
        printableName => __('File Sharing and Domain Services'),
        @_);
    bless ($self, $class);
    return $self;
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
        $self->getProvision->checkEnvironment($throwException);
    }

    $self->SUPER::enableService($status);

    my $dns = EBox::Global->modInstance('dns');
    $dns->setAsChanged();
}

# Method: _postServiceHook
#
#   Override this method to set the Shares permissions once Samba is reloaded and has the shares configured
#
# Overrides:
#
#   <EBox::Module::Service::_postServiceHook>
#
sub _postServiceHook
{
    my ($self, $enabled) = @_;

    # Execute the hook actions *only* if Samba module is enabled and we were invoked from the web application, this will
    # prevent that we execute this code with every service restart or on server boot delaying such processes.
    if ($enabled and ($0 =~ /\/global-action$/)) {

        # Only set global roaming profiles and drive letter options
        # if we are not replicating to another Windows Server to avoid
        # overwritting already existing per-user settings. Also skip if
        # unmanaged_home_directory config key is defined
        my $unmanagedHomes = EBox::Config::boolean('unmanaged_home_directory');
        unless ($self->mode() eq 'adc') {
            EBox::info("Setting roaming profiles...");
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
                $user->setHomeDrive($self->drive(), $drivePath, 1) unless $unmanagedHomes;
                $user->save();
            }
        }

        my $host = $self->ldb()->rootDse()->get_value('dnsHostName');
        unless (defined $host and length $host) {
            throw EBox::Exceptions::Internal('Could not get DNS hostname');
        }
        my $sambaShares = $self->model('SambaShares');
        my $domainSID = $self->ldb()->domainSID();
        my $domainAdminSID = "$domainSID-500";
        my $builtinAdministratorsSID = 'S-1-5-32-544';
        my $domainUsersSID = "$domainSID-513";
        my $domainGuestsSID = "$domainSID-514";
        my $systemSID = "S-1-5-18";
        my @superAdminSIDs = ($builtinAdministratorsSID, $domainAdminSID, $systemSID);
        my $readRights = SEC_FILE_EXECUTE | SEC_RIGHTS_FILE_READ;
        my $writeRights = SEC_RIGHTS_FILE_WRITE | SEC_STD_DELETE;
        my $adminRights = SEC_STD_ALL | SEC_RIGHTS_FILE_ALL;
        my $defaultInheritance = SEC_ACE_FLAG_CONTAINER_INHERIT | SEC_ACE_FLAG_OBJECT_INHERIT;
        for my $id (@{$sambaShares->ids()}) {
            my $row = $sambaShares->row($id);
            my $enabled     = $row->valueByName('enabled');
            my $shareName   = $row->valueByName('share');
            my $guestAccess = $row->valueByName('guest');
            my $recursiveAcls = $row->valueByName('recursive_acls');

            unless ($enabled) {
                next;
            }

            my $state = $self->get_state();
            if (not ((defined $state->{shares_set_rights}) and
                     ($state->{shares_set_rights}->{$shareName}))) {
                # share permissions didn't change, nothing needs to be done for this share.
                next;
            }

            EBox::info("Applying new permissions to the share '$shareName'...");

            my $smb = new EBox::Samba::SmbClient(
                target => $host, service => $shareName, RID => DOMAIN_RID_ADMINISTRATOR);

            # Set the client to case sensitive mode. The directory listing can
            # contain files inside folders with the same name but different
            # casing, so when trying to open them the library failes with a
            # NT_STATUS_OBJECT_NAME_NOT_FOUND error code. Setting the library
            # to case sensitive avoids this problem.
            $smb->case_sensitive(1);

            my $sd = new Samba::Security::Descriptor();
            my $sdControl = $sd->type();
            # Inherite all permissions.
            $sdControl |= SEC_DESC_DACL_AUTO_INHERITED;
            $sdControl |= SEC_DESC_DACL_PROTECTED;
            $sdControl |= SEC_DESC_SACL_AUTO_INHERITED;
            $sd->type($sdControl);
            # Set the owner and the group. We differ here from Windows because they just set the owner to
            # builtin/Administrators but this other setting should be compatible and better looking when using Linux
            # console.
            $sd->owner($domainAdminSID);
            $sd->group($builtinAdministratorsSID);

            # Always, full control to Builtin/Administrators group, Users/Administrator and System users.
            for my $superAdminSID (@superAdminSIDs) {
                my $ace = new Samba::Security::AccessControlEntry(
                    $superAdminSID, SEC_ACE_TYPE_ACCESS_ALLOWED, $adminRights, $defaultInheritance);
                $sd->dacl_add($ace);
            }

            if ($guestAccess) {
                # Add read/write access for Domain Users
                my $ace = new Samba::Security::AccessControlEntry(
                    $domainUsersSID, SEC_ACE_TYPE_ACCESS_ALLOWED, $readRights | $writeRights, $defaultInheritance);
                $sd->dacl_add($ace);
                # Add read/write access for Domain Guests
                my $ace2 = new Samba::Security::AccessControlEntry(
                    $domainGuestsSID, SEC_ACE_TYPE_ACCESS_ALLOWED, $readRights | $writeRights, $defaultInheritance);
                $sd->dacl_add($ace2);
            } else {
                for my $subId (@{$row->subModel('access')->ids()}) {
                    my $subRow = $row->subModel('access')->row($subId);
                    my $permissions = $subRow->elementByName('permissions');

                    my $userType = $subRow->elementByName('user_group');
                    my $account = $userType->printableValue();
                    my $qobject = shell_quote($account);

                    # Fix for Samba share ACLs for 'All users' are not written to filesystem
                    # map '__USERS__' to 'Domain Users' SID
                    my $accountShort = $userType->value();
                    my $sid = undef;

                    if ($accountShort eq '__USERS__') {
                        $sid = $domainUsersSID;
                        EBox::debug("Mapping group $accountShort to 'Domain Users' SID $sid");
                    } else {
                        my $object = new EBox::Samba::SecurityPrincipal(samAccountName => $account);
                        unless ($object->exists()) {
                            next;
                        }

                        $sid = $object->sid();
                    }
                    my $rights = undef;
                    if ($permissions->value() eq 'readOnly') {
                        $rights = $readRights;
                    } elsif ($permissions->value() eq 'readWrite') {
                        $rights = $readRights | $writeRights;
                    } elsif ($permissions->value() eq 'administrator') {
                        $rights = $adminRights;
                    } else {
                        my $type = $permissions->value();
                        EBox::error("Unknown share permission type '$type'");
                        next;
                    }
                    my $ace = new Samba::Security::AccessControlEntry(
                        $sid, SEC_ACE_TYPE_ACCESS_ALLOWED, $rights, $defaultInheritance);
                    $sd->dacl_add($ace);
                }
            }
            my $relativeSharePath = '/';
            EBox::info("Applying ACLs for top-level share $shareName");
            my $sinfo = SECINFO_OWNER |
                        SECINFO_GROUP |
                        SECINFO_DACL |
                        SECINFO_PROTECTED_DACL;
            my $access_mask = SEC_STD_WRITE_OWNER |
                              SEC_STD_READ_CONTROL |
                              SEC_STD_WRITE_DAC |
                              SEC_FILE_READ_ATTRIBUTE;
            my $attributes = FILE_ATTRIBUTE_NORMAL |
                             FILE_ATTRIBUTE_ARCHIVE |
                             FILE_ATTRIBUTE_DIRECTORY |
                             FILE_ATTRIBUTE_HIDDEN |
                             FILE_ATTRIBUTE_READONLY |
                             FILE_ATTRIBUTE_SYSTEM;
            EBox::debug("Setting NT ACL on file: $relativeSharePath");
            $smb->set_sd($relativeSharePath, $sd, $sinfo, $access_mask);
            # Apply recursively the permissions.
            my $shareContentList = $smb->list($relativeSharePath,
                attributes => $attributes, recursive => 1);
            # Reset the DACL_PROTECTED flag;
            $sdControl = $sd->type();
            $sdControl &= ~SEC_DESC_DACL_PROTECTED;
            $sd->type($sdControl);
            ## only replace ACLs for subdirs if recursiveAcls = 1
            if ($recursiveAcls) {
                foreach my $item (@{$shareContentList}) {
                    my $itemName = $item->{name};
                    $itemName =~ s/^\/\/(.*)/\/$1/s;
                    EBox::info("Replacing ACLs for $shareName$itemName");
                    $smb->set_sd($itemName, $sd, $sinfo, $access_mask);
                }
            }
            delete $state->{shares_set_rights}->{$shareName};
            $self->set_state($state);
        }

        # Change group ownership of quarantine_dir to __USERS__
        EBox::info("Fixing quarantine_dir permissions...");
        if ($self->defaultAntivirusSettings()) {
            $self->_setupQuarantineDirectory();
        }

        # Write DNS update list
        EBox::info("Writing DNS update list...");
        $self->_writeDnsUpdateList();
    } else {
        EBox::debug("Ignoring Samba's _postServiceHook code because it was not invoked from the web application.");
    }

    return $self->SUPER::_postServiceHook($enabled);
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

sub _startDaemon
{
    my ($self, $daemon, %params) = @_;

    $self->SUPER::_startDaemon($daemon, %params);

    if ($daemon->{name} eq 'samba4') {
        my $services = $self->_services();
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
        EBox::debug("Wait samba task '$desc'");
    } else {
        EBox::debug("Wait unknown samba task");
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
        EBox::warn("Timeout reached while waiting for samba service '$desc' ($proto)");
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
    $self->checkUsersMode();

    # Remount filesystem with user_xattr and acl options
    EBox::info('Setting up filesystem');
    EBox::Sudo::root(EBox::Config::scripts('samba') . 'setup-filesystem');

    # Create directories
    EBox::info('Creating directories');
    $self->_createDirectories();

    # Load the required OpenLDAP schema updates.
    $self->performLDAPActions();
}

sub getProvision
{
    my ($self) = @_;
    unless (defined $self->{provision}) {
        $self->{provision} = new EBox::Samba::Provision();
    }
    return $self->{provision};
}

sub isProvisioned
{
    my ($self) = @_;

    return $self->getProvision->isProvisioned();
}

# Method: shares
#
#   It returns the custom shares
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
    my ($self) = @_;

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
        $shareConf->{'type'} = $path->selectedType();
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

# Implement EBox::SyncFolders::Provider interface
sub syncFolders
{
    my ($self) = @_;

    # sync all shares
    my $sshares = $self->model('SyncShares');
    my $shares = $self->model('SambaShares');

    my $syncAll = $sshares->row()->valueByName('sync');
    my @folders;
    for my $id (@{$shares->enabledRows()}) {
        my $row = $shares->row($id);
        my $sync = $row->valueByName('sync');

        my $path = $row->elementByName('path');
        if ($path->selectedType() eq 'zentyal') {
            $path = SHARES_DIR . '/' . $path->value();
        } else {
            $path = $path->value();
        }

        if ($sync or $syncAll) {
            push (@folders, new EBox::SyncFolders::Folder($path, 'share', name => basename($path)));
        }
    }

    if ($self->recoveryEnabled()) {
        foreach my $share ($self->filesystemShares()) {
            push (@folders, new EBox::SyncFolders::Folder($share, 'recovery'));
        }
    }

    return \@folders;
}

sub recoveryDomainName
{
    return __('Filesystem shares');
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

    # Provide a default config and override with the conf file if exists
    my $avModel = $self->model('AntivirusDefault');
    my $conf = {
        show_special_files       => 'True',
        rm_hidden_files_on_rmdir => 'True',
        recheck_time_open        => '50',
        recheck_tries_open       => '100',
        allow_nonscanned_files   => 'False',
    };

    foreach my $key (keys %{$conf}) {
        my $value = EBox::Config::configkey($key);
        $conf->{$key} = $value if $value;
    }

    # Hard coded settings
    $conf->{quarantine_dir} = $avModel->QUARANTINE_DIR();
    $conf->{domain_socket}  = 'True';
    $conf->{socketname}     = $avModel->ZAVS_SOCKET();

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

sub _writeDnsUpdateList
{
    my ($self) = @_;

    my $array = [];
    my $partitions = ['DomainDnsZones', 'ForestDnsZones'];
    push (@{$array}, partitions => $partitions);
    $self->writeConfFile(SAMBA_DNS_UPDATE_LIST,
                         'samba/dns_update_list.mas', $array,
                         { 'uid' => '0', 'gid' => '0', mode => '644' });
}

sub writeSambaConfig
{
    my ($self) = @_;

    my $netbiosName = $self->netbiosName();
    my $realmName   = EBox::Global->modInstance('users')->kerberosRealm();

    my $prefix = EBox::Config::configkey('custom_prefix');
    $prefix = 'zentyal' unless $prefix;

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $hostDomain = $sysinfo->hostDomain();

    my @array = ();
    push (@array, 'fs'          => EBox::Config::configkey('samba_fs'));
    push (@array, 'prefix'      => $prefix);
    push (@array, 'workgroup'   => $self->workgroup());
    push (@array, 'netbiosName' => $netbiosName);
    push (@array, 'description' => $self->description());
    push (@array, 'mode'        => 'dc');
    push (@array, 'realm'       => $realmName);
    push (@array, 'domain'      => $hostDomain);
    push (@array, 'roamingProfiles' => $self->roamingProfiles());
    push (@array, 'profilesPath' => PROFILES_DIR);
    push (@array, 'sysvolPath'  => SYSVOL_DIR);
    push (@array, 'disableFullAudit' => EBox::Config::boolean('disable_fullaudit'));
    push (@array, 'unmanagedAcls'    => EBox::Config::boolean('unmanaged_acls'));

    if (EBox::Global->modExists('printers')) {
        my $printersModule = EBox::Global->modInstance('printers');
        push (@array, 'print' => 1) if ($printersModule->isEnabled());
    }

    push (@array, 'shares' => $self->shares());

    push (@array, 'antivirus' => $self->defaultAntivirusSettings());
    push (@array, 'antivirus_exceptions' => $self->antivirusExceptions());
    push (@array, 'antivirus_config' => $self->antivirusConfig());
    push (@array, 'recycle' => $self->defaultRecycleSettings());
    push (@array, 'recycle_exceptions' => $self->recycleExceptions());
    push (@array, 'recycle_config' => $self->recycleConfig());

    if (EBox::Global->modExists('openchange')) {
        my $openchangeModule = EBox::Global->modInstance('openchange');
        my $openchangeEnabled = $openchangeModule->isEnabled();
        my $openchangeProvisioned = $openchangeModule->isProvisioned();
        push (@array, 'openchangeEnabled' => $openchangeEnabled);
        push (@array, 'openchangeProvisioned' => $openchangeProvisioned);
    }

    $self->writeConfFile(SAMBACONFFILE,
                         'samba/smb.conf.mas', \@array);

    $self->_writeAntivirusConfig();
}

sub _writeAntivirusConfig
{
    my ($self) = @_;

    return unless EBox::Global->modExists('antivirus');

    my $avModule = EBox::Global->modInstance('antivirus');
    my $avModel = $self->model('AntivirusDefault');

    my $conf = {};
    $conf->{clamavSocket} = $avModule->CLAMD_SOCKET();
    $conf->{quarantineDir} = $avModel->QUARANTINE_DIR();
    $conf->{zavsSocket}  = $avModel->ZAVS_SOCKET();
    $conf->{nThreadsConf} = EBox::Config::configkey('scanning_threads');

    write_file(ANTIVIRUS_CONF, encode_json($conf));
}

sub _setupQuarantineDirectory
{
    my ($self) = @_;

    my $zentyalUser = EBox::Config::user();
    my $nobodyUser  = GUEST_DEFAULT_USER;
    my $avModel     = $self->model('AntivirusDefault');
    my $quarantine  = $avModel->QUARANTINE_DIR();
    my @cmds;
    push (@cmds, "mkdir -p '$quarantine'");
    push (@cmds, "chown -R $zentyalUser.adm '$quarantine'");
    push (@cmds, "chmod 770 '$quarantine'");
    push (@cmds, "setfacl -R -m u:$nobodyUser:rwx g:adm:rwx '$quarantine'");

    # Grant access to domain admins
    my $domainAdminsSid = $self->ldb->domainSID() . '-512';
    my $domainAdminsGroup = new EBox::Samba::Group(sid => $domainAdminsSid);
    if ($domainAdminsGroup->exists()) {
        my @domainAdmins = $domainAdminsGroup->get('member');
        foreach my $memberDN (@domainAdmins) {
            my $user = new EBox::Samba::User(dn => $memberDN);
            if ($user->exists()) {
                my $uid = $user->get('samAccountName');
                push (@cmds, "setfacl -m u:$uid:rwx '$quarantine'");
            }
        }
    }
    EBox::Sudo::silentRoot(@cmds);
}

sub _createDirectories
{
    my ($self) = @_;

    my $zentyalUser = EBox::Config::user();
    my $group = EBox::Users::DEFAULTGROUP();
    my $nobody = GUEST_DEFAULT_USER;
    my $avModel = $self->model('AntivirusDefault');
    my $quarantine = $avModel->QUARANTINE_DIR();

    my @cmds;
    push (@cmds, 'mkdir -p ' . SAMBA_DIR);
    push (@cmds, "chown root:$group " . SAMBA_DIR);
    push (@cmds, "chmod 770 " . SAMBA_DIR);
    push (@cmds, "setfacl -b " . SAMBA_DIR);
    push (@cmds, "setfacl -m u:$nobody:rx " . SAMBA_DIR);
    push (@cmds, "setfacl -m u:$zentyalUser:rwx " . SAMBA_DIR);

    push (@cmds, 'mkdir -p ' . PROFILES_DIR);
    push (@cmds, "chown root:$group " . PROFILES_DIR);
    push (@cmds, "chmod 770 " . PROFILES_DIR);
    push (@cmds, "setfacl -b " . PROFILES_DIR);

    push (@cmds, 'mkdir -p ' . SHARES_DIR);
    push (@cmds, "chown root:$group " . SHARES_DIR);
    push (@cmds, "chmod 770 " . SHARES_DIR);
    push (@cmds, "setfacl -b " . SHARES_DIR);
    push (@cmds, "setfacl -m u:$nobody:rx " . SHARES_DIR);
    push (@cmds, "setfacl -m u:$zentyalUser:rwx " . SHARES_DIR);

    push (@cmds, "mkdir -p '$quarantine'");
    push (@cmds, "chown -R $zentyalUser.adm '$quarantine'");
    push (@cmds, "chmod 770 '$quarantine'");

    EBox::Sudo::root(@cmds);
}

sub _setConf
{
    my ($self) = @_;

    return unless $self->configured() and $self->isEnabled();

    my $prov = $self->getProvision();
    if ((not $prov->isProvisioned()) or $self->get('need_reprovision')) {
        if ($self->get('need_reprovision')) {
            # Current provision is not useful, change back status to not provisioned.
            $prov->setProvisioned(0);
            # The LDB connection needs to be reset so we stop using cached values.
            $self->ldb()->clearConn()
        }
        $prov->provision();
        $self->unset('need_reprovision');
    }

    $self->writeSambaConfig();

    # Fix permissions on samba dirs. Zentyal user needs access because
    # the antivirus daemon runs as 'ebox'
    $self->_createDirectories();

    # Remove shares
    $self->model('SambaDeletedShares')->removeDirs();
    # Create shares
    $self->model('SambaShares')->createDirs();
}

sub _adcMode
{
    my ($self) = @_;

    my $settings = $self->model('GeneralSettings');
    return ($settings->modeValue() eq $settings->MODE_ADC());
}

sub _nmbdCond
{
    my ($self) = @_;

    return (-f SAMBACONFFILE);
}

sub _sysvolSyncCond
{
    my ($self) = @_;

    return ($self->isEnabled() and $self->getProvision->isProvisioned() and $self->_adcMode());
}

sub _s4syncCond
{
    my ($self) = @_;

    return ($self->isEnabled() and $self->getProvision->isProvisioned());
}

sub _antivirusEnabled
{
    my ($self) = @_;

    my $avModule = EBox::Global->modInstance('antivirus');
    unless (defined ($avModule) and $avModule->isEnabled()) {
        return 0;
    }

    my $avModel = $self->model('AntivirusDefault');
    my $enabled = $avModel->value('scan');

    return $enabled;
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
            type => 'init.d',
            pidfiles => ['/opt/samba4/var/run/samba.pid'],
        },
        {
            name => 'zentyal.nmbd',
            precondition => \&_nmbdCond,
        },
        {
            name => 'zentyal.s4sync',
            precondition => \&_s4syncCond,
        },
        {
            name => 'zentyal.sysvol-sync',
            precondition => \&_sysvolSyncCond,
        },
        {
            name => 'zentyal.zavsd',
            precondition => \&_antivirusEnabled,
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

# Method: firewallCaptivePortalExceptions
#
#  this method gives firewall ruels to add to the captive portal module.
#  They purpose is to allow domain joins without captive portal interference
sub firewallCaptivePortalExceptions
{
    my ($self, $chain) = @_;
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

    my $folder = new EBox::Menu::Folder(name  => 'Domain',
                                        text      => __('Domain'),
                                        icon      => 'domain',
                                        separator => 'Office',
                                        order     => 535);

    $folder->add(new EBox::Menu::Item(url   => 'Samba/View/GeneralSettings',
                                      text  => __('Settings'),
                                      order => 10));
    $folder->add(new EBox::Menu::Item(url   => 'Samba/View/GPOs',
                                      text  => __('Group Policy Objects'),
                                      order => 20));
    $folder->add(new EBox::Menu::Item(url   => 'Samba/Tree/GPOLinks',
                                      text  => __('Group Policy Links'),
                                      order => 30));

    $root->add(new EBox::Menu::Item(text      => __('File Sharing'),
                                    url       => 'Samba/Composite/General',
                                    icon      => 'samba',
                                    separator => 'Office',
                                    order     => 540));

    $root->add($folder);
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
    $hostName = substr($hostName, 0, 15);

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
    my $value = substr($parts[0], 0, 15);
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

    return ucfirst($prefix) . ' Server';
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

    my @cmds;

    if ($self->_s4syncCond()) {
        try {
            EBox::Service::manage('zentyal.s4sync', 'stop');
        } catch {
        }
    }

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
        EBox::Service::manage('zentyal.s4sync', 'start') if $self->_s4syncCond();
        $e->throw();
    }
    EBox::Service::manage('zentyal.s4sync', 'start') if $self->_s4syncCond();

    # Backup admin password
    unless ($options{bug}) {
        my $pwdFile = EBox::Config::conf() . 'samba.passwd';
        # Additional domain controllers does not have stashed pwd
        if (EBox::Sudo::fileTest('-f', $pwdFile)) {
            EBox::Sudo::root("cp '$pwdFile' $dir");
        }
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
}

# Method: depends
#
#     Samba depends on users only to ensure proper order during
#     save changes when reprovisioning (after host/domain change)
#
# Overrides:
#
#     <EBox::Module::Base::depends>
#
sub depends
{
    my ($self) = @_;

    my @deps = ('network', 'printers');

    if ($self->get('need_reprovision')) {
        push (@deps, 'users');
    }

    return \@deps;
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
        'username' => __('User'),
        'filename' => __('File name'),
        'virus' => __('Virus'),
        'event' => __('Type'),
    };
    my @virus_order = qw(timestamp client username filename virus event);;
    my $virus_events = { 'virus' => __('Virus') };

    my $quarantine_titles = {
        'timestamp' => __('Date'),
        'client' => __('Client address'),
        'username' => __('User'),
        'filename' => __('File name'),
        'qfilename' => __('Quarantined file name'),
        'event' => __('Quarantine'),
    };
    my @quarantine_order = qw(timestamp client username filename qfilename event);
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
        'types' => { 'client' => 'IPAddr' },
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
#    foreach my $sh_r (@{ $self->shares() }) {
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
#    foreach my $sh_r (@{ $self->shares()  }) {
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

# Method: filesystemShares
#
#   This function is used for Disaster Recovery, to get
#   the paths of the filesystem shares.
#
sub filesystemShares
{
    my ($self) = @_;

    my $shares = $self->shares();
    my $paths = [];

    foreach my $share (@{$shares}) {
        if ($share->{type} eq 'system') {
            push (@{$paths}, $share->{path});
        }
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

    my $userProfilesPath = PROFILES_DIR;

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
    my $shares = $self->shares();
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

    @sharesSortedByPathLen = ();

    # Group and custom shares
    foreach my $sh_r (@{ $self->shares() }) {
        push @sharesSortedByPathLen, {path => $sh_r->{path},
                                      share =>  $sh_r->{share},
                                      type => ($sh_r->{'groupShare'} ? 'Group' : 'Custom')};
    }

    # User shares
    foreach my $user (@{ $self->userShares() }) {
        foreach my $share (@{$user->{'shares'}}) {
            my $entry = {};
            $entry->{'share'} = $user->{'user'};
            $entry->{'type'} = 'User';
            $entry->{'path'} = $share;
            push (@sharesSortedByPathLen, $entry);
        }
    }

    # add regexes
    foreach my $share (@sharesSortedByPathLen) {
        my $path = $share->{path};
        # Remove duplicate '/'
        $path =~ s/\/+/\//g;
        $share->{pathRegex} = qr{^$path/};
    }

    @sharesSortedByPathLen = sort {
        length($b->{path}) <=>  length($a->{path})
    } @sharesSortedByPathLen;
}

#   Returns a hash with:
#       share - The name of the share
#       path  - The path of the share
#       type  - The type of the share (User, Group, Custom)
sub shareByFilename
{
    my ($self, $filename) = @_;

    if (not @sharesSortedByPathLen) {
        my $samba =EBox::Global->modInstance('samba');
        $samba->_updatePathsByLen();
    }

    foreach my $shareAndPath (@sharesSortedByPathLen) {
        if ($filename =~ m/$shareAndPath->{pathRegex}/) {
            return $shareAndPath;
        }
    }

    return undef;
}

######################################
##  SysInfo observer implementation ##
######################################

# Method: hostNameChanged
#
#   Disallow domainname changes if module is configured
#
sub hostNameChanged
{
    my ($self, $oldHostName, $newHostName) = @_;

    $self->_hostOrDomainChanged();
}

# Method: hostNameChangedDone
#
#   This method updates the computer netbios name if the module has not
#   been configured yet
#
sub hostNameChangedDone
{
    my ($self, $oldHostName, $newHostName) = @_;

    my $settings = $self->model('GeneralSettings');
    $settings->setValue('netbiosName', $newHostName);
}

# Method: hostDomainChanged
#
#   Disallow hostname changes if module is configured
#
sub hostDomainChanged
{
    my ($self, $oldDomainName, $newDomainName) = @_;

    $self->_hostOrDomainChanged();
}

sub _hostOrDomainChanged
{
    my ($self) = @_;

    if ($self->configured()) {
        if ($self->_adcMode()) {
            throw EBox::Exceptions::UnwillingToPerform(
                reason => __('The hostname or domain cannot be changed if Zentyal is configured as additional domain controller.')
            );
        }

        $self->set('need_reprovision', 1);
    }
}

# Method: hostDomainChangedDone
#
#   This method updates the samba domain if the module has not been
#   configured yet
#
sub hostDomainChangedDone
{
    my ($self, $oldDomainName, $newDomainName) = @_;

    my $settings = $self->model('GeneralSettings');
    $settings->setValue('realm', uc ($newDomainName));

    my @parts = split (/\./, $newDomainName);
    my $value = substr($parts[0], 0, 15);
    $value = 'ZENTYAL-DOMAIN' unless defined $value;
    $value = uc ($value);
    $settings->setValue('workgroup', $value);
}

# Method: gpos
#
#   Returns the Domain GPOs
#
# Returns:
#
#   Array ref containing instances of EBox::Samba::GPO
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
        push (@{$gpos}, new EBox::Samba::GPO(entry => $entry));
    }

    return $gpos;
}

sub computers
{
    my ($self, $system) = @_;

    return [] unless $self->isProvisioned();

    my $sort = new Net::LDAP::Control::Sort(order => 'name');
    my %args = (
        base => $self->ldb()->dn(),
        filter => 'objectClass=computer',
        scope => 'sub',
        control => [$sort],
    );

    my $result = $self->ldb->search(\%args);

    my @computers;
    foreach my $entry ($result->entries()) {
        my $computer = new EBox::Samba::Computer(entry => $entry);
        next unless $computer->exists();
        push (@computers, $computer);
    }

    return \@computers;
}

# Method: ldapObjectFromLDBObject
#
#   Return the perl Object that handles in OpenLDAP the given perl object from Samba or undef if not found.
#
sub ldapObjectFromLDBObject
{
    my ($self, $ldbObject) = @_;

    unless ($ldbObject) {
        throw EBox::Exceptions::MissingArgument('ldbObject')
    }
    unless ($ldbObject->isa('EBox::Samba::LdbObject')) {
        throw EBox::Exceptions::InvalidType('ldbObject', 'EBox::Samba::LdbObject');
    }

    my $usersMod = EBox::Global->modInstance('users');

    if ($ldbObject->isa('EBox::Samba::NamingContext')) {
        return $usersMod->defaultNamingContext();
    }

    my $objectGUID = $ldbObject->objectGUID();
    return $self->ldapObjectByObjectGUID($objectGUID);
}

# Method: ldbObjectFromLDAPObject
#
#   Return the perl Object that handles in Samba the given perl object from OpenLDAP or undef if not found.
#
sub ldbObjectFromLDAPObject
{
    my ($self, $ldapObject) = @_;

    throw EBox::Exceptions::MissingArgument('ldapObject') unless ($ldapObject);
    throw EBox::Exceptions::InvalidType('ldapObject', 'EBox::Users::LdapObject') unless ($ldapObject->isa('EBox::Users::LdapObject'));

    if ($ldapObject->isa('EBox::Users::NamingContext')) {
        return $self->defaultNamingContext();
    }

    my $objectGUID = $ldapObject->get('msdsObjectGUID');
    if ($objectGUID) {
        return $self->ldbObjectByObjectGUID($objectGUID);
    } else {
        EBox::debug("Unable to find the LDB object for LDAP's DN: " . $ldapObject->dn());
        return undef;
    }
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

    unless (defined $entry) {
        throw EBox::Exceptions::MissingArgument('entry');
    }

    my $object;
    my $anyObjectClasses = any($entry->get_value('objectClass'));
    my @entryClasses =qw(EBox::Samba::OU EBox::Samba::User EBox::Samba::Contact EBox::Samba::Group EBox::Samba::Container EBox::Samba::BuiltinDomain);
    foreach my $class (@entryClasses) {
        if ($class->mainObjectClass eq $anyObjectClasses) {
            return $class->new(entry => $entry);
        }
    }

    my $ldb = $self->ldb();
    if ($entry->dn() eq $ldb->dn()) {
        return $self->defaultNamingContext();
    }

    EBox::warn("Ignored unknown perl object for DN: " . $entry->dn());
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

    my $baseDN = $self->ldb()->dn();

    return '' if ($dn eq $baseDN);

    if (not $dn =~ s/,$baseDN$//) {
        throw EBox::Exceptions::Internal("$dn is not contained in $baseDN");
    }

    return $dn;
}

# Method: ldapObjectByObjectGUID
#
#   Return the ldap perl object modeling the given objectGUID or undef if not found.
#
# Parameters:
#
#   objectGUID - The objectGUID id.
#
sub ldapObjectByObjectGUID
{
    my ($self, $objectGUID) = @_;

    my $usersMod = EBox::Global->modInstance('users');
    my $base = $usersMod->ldap()->dn();
    my $filter = "(&(objectClass=zentyalSambaLink)(msdsObjectGUID=$objectGUID))";
    my $scope = 'sub';

    my $attrs = {
        base   => $base,
        filter => $filter,
        scope  => $scope,
        attrs  => ['*', 'entryUUID'],
    };

    my $result = $usersMod->ldap->search($attrs);
    return undef unless ($result);

    if ($result->count() > 1) {
        throw EBox::Exceptions::Internal(
            __x('Found {count} results for, expected only one.',
                count => $result->count()));
    }

    my $entry = $result->entry(0);
    if ($entry) {
        return $usersMod->entryModeledObject($entry);
    } else {
        return undef;
    }
}

# Method: ldbObjectByObjectGUID
#
#   Return the perl object modeling the given objectGUID or undef if not found.
#
# Parameters:
#
#   objectGUID - The objectGUID id.
#
sub ldbObjectByObjectGUID
{
    my ($self, $objectGUID) = @_;

    unless (defined $objectGUID) {
        throw EBox::Exceptions::MissingArgument('objectGUID');
    }

    my $baseObject = new EBox::Samba::LdbObject(objectGUID => $objectGUID);
    if ($baseObject->exists()) {
        my $object = $self->entryModeledObject($baseObject->_entry());
        return $object;
    }

    return undef;
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
    my $ldb = $self->ldb();
    if ($dn eq $ldb->dn()) {
        return $self->defaultNamingContext();
    }

    my $baseObject = new EBox::Samba::LdbObject(dn => $dn);

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
sub defaultNamingContext
{
    my ($self) = @_;

    my $ldb = $self->ldb;
    return new EBox::Samba::NamingContext(dn => $ldb->dn());
}

# Method: hiddenSid
#
#   Check if the specified LDB object belongs to the list of regexps
#   of SIDs to hide on the UI read from /etc/zentyal/sids-to-hide.regex
#
sub hiddenSid
{
    my ($self, $object) = @_;

    unless (defined $object) {
        throw EBox::Exceptions::MissingArgument('object');
    }

    unless ($object->can('sid')) {
        return 0;
    }

    unless ($self->{sidsToHide}) {
        $self->{sidsToHide} = $self->_sidsToHide();
    }

    foreach my $ignoredSidMask (@{$self->{sidsToHide}}) {
       return 1 if ($object->sid() =~ m/$ignoredSidMask/);
    }

    return 0;
}

sub _sidsToHide
{
    my ($self) = @_;

    my $ignoredSidsFile = EBox::Config::etc() . 'sids-to-hide.regex';
    my @lines = read_file($ignoredSidsFile);
    my @sidsTmp = grep(/^\s*S-/, @lines);
    my @sids = map { s/\n//; $_; } @sidsTmp;

    return \@sids;
}

1;
