# Copyright (C) 2008-2010 eBox Technologies S.L.
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

use base qw(EBox::Module::Service EBox::LdapModule EBox::FirewallObserver
            EBox::Report::DiskUsageProvider EBox::Model::CompositeProvider
            EBox::Model::ModelProvider EBox::LogObserver);

use EBox::Sudo;
use EBox::Global;
use EBox::Service;
use EBox::SambaLdapUser;
use EBox::UsersAndGroups;
use EBox::Network;
use EBox::SambaFirewall;
use EBox::SambaLogHelper;
use EBox::Dashboard::Widget;
use EBox::Dashboard::List;
use EBox::Menu::Item;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Config;
use EBox::Model::ModelManager;
use EBox::DBEngineFactory;


use File::Slurp qw(read_file write_file);
use Perl6::Junction qw(all any);
use Error qw(:try);
use Sys::Hostname;

use constant SMBCONFFILE          => '/etc/samba/smb.conf';
use constant CLAMAVSMBCONFFILE    => '/etc/samba/vscan-clamav.conf';
use constant SMBLDAPTOOLBINDFILE  => '/etc/smbldap-tools/smbldap_bind.conf';
use constant SMBLDAPTOOLBINDFILE_MASK => '0600';
use constant SMBLDAPTOOLBINDFILE_UID => '0';
use constant SMBLDAPTOOLBINDFILE_GID => '0';
use constant SMBLDAPTOOLCONFFILE  => '/etc/smbldap-tools/smbldap.conf';
use constant SMBPIDFILE           => '/var/run/samba/smbd.pid';
use constant NMBPIDFILE           => '/var/run/samba/nmbd.pid';
use constant MAXNETBIOSLENGTH     => 15;
use constant MAXWORKGROUPLENGTH   => 32;
use constant MAXDESCRIPTIONLENGTH => 255;
use constant SMBPORTS => qw(137 138 139 445);
use constant NETLOGONDIR          => '/home/samba/netlogon';
use constant NETLOGONSCRIPT       => 'logon.bat';
use constant NETLOGONDEFAULTSCRIPT=> 'zentyal-logon.bat';


use constant FIX_SID_PROGRAM => '/usr/share/ebox-samba/ebox-fix-sid';
use constant QUOTA_PROGRAM => '/usr/share/ebox-samba/ebox-samba-quota';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'samba',
            printableName => __n('File Sharing'),
            domain => 'ebox-samba',
            @_);
    bless($self, $class);
    return $self;
}

# Method: bootDepends
#
#     Samba depends on CUPS only if printers module enabled.
#
# Overrides:
#
#     <EBox::Module::Base::depends>
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
#	Override EBox::Module::Service::actions
#
sub actions
{
    return [
    {
        'action' => __('Create Samba home directory for shares and groups'),
        'reason' => __('Zentyal will create the directories for Samba ' .
                       'shares and groups under /home/samba.'),
        'module' => 'samba'
    },
    {
        'action' => __('Add LDAP schemas'),
        'reason' => __('Zentyal will add two LDAP schemas to the LDAP directory:' .
                       ' samba and ebox.'),
        'module' => 'samba'
    },
    {
        'action' => __('Set Samba LDAP admin dn password'),
        'reason' => __('Zentyal will configure Samba to use the LDAP admin dn ' .
                       'password.'),
        'module' => 'samba'
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
        'file' => SMBCONFFILE,
            'reason' => __('To set up Samba according to your configuration.'),
        'module' => 'samba'
    },
    {
        'file' => SMBLDAPTOOLCONFFILE,
        'reason' => __('To set up smbldap-tools according to your' .
            ' configuration.'),
        'module' => 'samba'
    },
    {
        'file' => SMBLDAPTOOLBINDFILE,
        'reason' => __('To set up smbldap-tools according to your LDAP' .
            ' configuration.'),
        'module' => 'samba'
    },
    {
        'file' => '/etc/fstab',
        'reason' => __('To add quota support to /home partition.'),
        'module' => 'samba'
    },
    {
        'file' => CLAMAVSMBCONFFILE,
        'reason' => __('To set the antivirus settings for Samba.'),
        'module' => 'samba'
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

    $self->performLDAPActions();

    my $users = EBox::Global->modInstance('users');

    EBox::Sudo::root(EBox::Config::share() . '/ebox-samba/ebox-samba-enable');
}

# Method: modelClasses
#
# Overrides:
#
#       <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{

    my ($self) = @_;

    return  [
               'EBox::Samba::Model::GeneralSettings',
               'EBox::Samba::Model::PDC',
               'EBox::Samba::Model::SambaShares',
               'EBox::Samba::Model::SambaSharePermissions',
               'EBox::Samba::Model::DeletedSambaShares',
               'EBox::Samba::Model::AntivirusDefault',
               'EBox::Samba::Model::AntivirusExceptions',
               'EBox::Samba::Model::RecycleDefault',
               'EBox::Samba::Model::RecycleExceptions',
               'EBox::Samba::Model::SambaUser',
           ];

}

# Method: compositeClasses
#
# Overrides:
#
#       <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{

    my ($self) = @_;

    return [
             'EBox::Samba::Composite::General',
             'EBox::Samba::Composite::Antivirus',
             'EBox::Samba::Composite::RecycleBin',
           ];
}

# Method: shares
#
#   It returns the custom shares 8
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
#   readOnly - string containing users and groups with read-only permissions
#   readWrite - string containing users and groups with read and write
#               permissions
#   administrators  - string containing users and groups with admin priviliges
#                   on the share
#   validUsers - readOnly + readWrite + administrators
sub shares
{
    my ($self, $all) = @_;
    my $shares = $self->model('SambaShares');
    my @shares;

    for my $id (@{$shares->enabledRows()}) {
        my $row = $shares->row($id);
        my @readOnly;
        my @readWrite;
        my @administrators;
        my $shareConf;

        $shareConf->{'share'} = $row->elementByName('share')->value();
        $shareConf->{'comment'} = $row->elementByName('comment')->value();

        my $path = $row->elementByName('path');

        if ($path->selectedType() eq 'ebox') {
            $shareConf->{'path'} = '/home/samba/shares/';
        }
        $shareConf->{'path'} .= $path->value();

        $shareConf->{'guest'} = $row->elementByName('guest')->value();

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
    return $antivirus->row()->valueByName('scan');
}

sub antivirusExceptions
{
    my ($self) = @_;
    my $model = $self->model('AntivirusExceptions');
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
    my @keys = ('repository', 'directory_mode', 'keeptree', 'versions',
                'maxsize', 'exclude', 'excludedir', 'noversions');

    foreach my $key (@keys) {
        my $value = EBox::Config::configkey($key);
        if ($value) {
            $conf->{$key} = $value;
        }
    }

    return $conf;
}

sub _exposedMethods
{
    return {
            'getPathByShareName' => {
            'action' => 'get',
                'path' => [ 'SambaShares'],
                'indexes' => [ 'share'],
                'selector' => [ 'path']
            },
            'getUserByIndex' => {
                'action' => 'get',
                'path' => [ 'SambaShares',
                'access'
                    ],
                'indexes' => ['share', 'id'],
                'selector' => ['user_group']
            },
            'getPermissionsByIndex' => {
                'action' => 'get',
                'path' => [ 'SambaShares',
                'access'
                    ],
                'indexes' => ['share', 'id'],
                'selector' => ['permissions']
            }
    };
}


# return interface upon samba should listen
# XXX this is a quick fix for this version. See #529
sub sambaInterfaces
{
    my ($self) = @_;
    my @ifaces;

    my $global = EBox::Global->getInstance();

    my $net = $global->modInstance('network');

    my $listen_external = EBox::Config::configkey('listen_external');

    my $netIfaces;
    if ($listen_external eq 'yes') {
        $netIfaces = $net->allIfaces;
    } else {
        $netIfaces = $net->InternalIfaces;
    }

    foreach my $iface (@{ $netIfaces }) {
        push @ifaces, $iface;

        if ( $net->ifaceMethod($iface) eq 'bridged' ) {
            my $br = $net->ifaceBridge($iface);
            push (@ifaces, "br$br");
            next;
        }

        my $vifacesNames = $net->vifaceNames($iface);
        if (defined $vifacesNames) {
            push @ifaces, @{  $vifacesNames };
        }

    }

    my @moduleGeneratedIfaces = ();

    # XXX temporal  fix until #529 is fixed
    if ($global->modExists('openvpn')) {
        my $openvpn = $global->modInstance('openvpn');
        my @openvpnDaemons = $openvpn->activeDaemons();
        my @openvpnIfaces  = map { $_->iface() }  @openvpnDaemons;

        push @moduleGeneratedIfaces, @openvpnIfaces;
    }

    push @ifaces, @moduleGeneratedIfaces;
    return \@ifaces;
}

sub _preSetConf
{
    my ($self) = @_;

    $self->_stopService();
}

sub _setConf
{
    my ($self) = @_;

    my $net = EBox::Global->modInstance('network');
    my $interfaces = join (',', ('lo', @{ $self->sambaInterfaces() }));

    my $ldap = $self->ldap;

    my $smbimpl = new EBox::SambaLdapUser;

    $smbimpl->setSambaDomainName($self->workgroup) ;
    $smbimpl->updateNetbiosName($self->netbios);
    $smbimpl->updateSIDEntries();


    my $ldapconf = $ldap->ldapConf();
    $ldapconf->{'users'} = EBox::UsersAndGroups::USERSDN;
    $ldapconf->{'groups'} = EBox::UsersAndGroups::GROUPSDN;

    my @array = ();
    push(@array, 'netbios'   => $self->netbios);
    push(@array, 'desc'      => $self->description);
    push(@array, 'workgroup' => $self->workgroup);
    push(@array, 'drive'     => $self->drive);
    push(@array, 'ldap'      => $ldapconf);
    push(@array, 'dirgroup'  => $smbimpl->groupShareDirectories);
    push(@array, 'ifaces'    => $interfaces);
    push(@array, 'printers'  => $self->_sambaPrinterConf());
    push(@array, 'active_printer' => $self->printerService());
    push(@array, 'pdc' => $self->pdc());
    push(@array, 'roaming' => $self->roamingProfiles());
    push(@array, 'backup_path' => EBox::Config::conf() . '/backups');
    push(@array, 'quarantine_path' => EBox::Config::var() . '/lib/ebox/quarantine');
    my $shares = $self->shares();
    push(@array, 'shares' => $shares);
    my $guestShares = 0;
    foreach my $share (@{$shares}) {
        if ($share->{'guest'}) {
            $guestShares = 1;
            last;
        }
    }
    push(@array, 'guest_shares' => $guestShares);
    push(@array, 'antivirus' => $self->defaultAntivirusSettings());
    push(@array, 'antivirus_exceptions' => $self->antivirusExceptions());
    push(@array, 'recycle' => $self->defaultRecycleSettings());
    push(@array, 'recycle_exceptions' => $self->recycleExceptions());
    push(@array, 'recycle_config' => $self->recycleConfig());

    if ($self->pdc()) {
        my $logonScript = join('/', NETLOGONDIR, NETLOGONSCRIPT);
        if (EBox::Sudo::fileTest('-f', $logonScript)) {
            push(@array, 'logon_script', NETLOGONSCRIPT);
        }
        $self->writeConfFile(join('/', NETLOGONDIR, NETLOGONDEFAULTSCRIPT),
            'samba/logon.bat.mas', \@array);
    }

    $self->writeConfFile(SMBCONFFILE, 'samba/smb.conf.mas', \@array);

    $self->writeConfFile(CLAMAVSMBCONFFILE, 'samba/vscan-clamav.conf.mas',
        \@array);

    EBox::Sudo::root(EBox::Config::share() . '/ebox-samba/ebox-setadmin-pass');

    my $users = EBox::Global->modInstance('users');

    $self->setSambaLdapToolsConf();

    # Set SIDs using the net tool this is neccesary bz if we change the
    #  domain name we can lost the domain SID
    my $sid = $self->_sidFromLdap();
    defined $sid or $sid = $smbimpl->alwaysGetSID();
    $self->setNetSID($sid);

    # Remove shares
    $self->model('DeletedSambaShares')->removeDirs();
    # Create samba shares
    $self->model('SambaShares')->createDirs();

    # Change group ownership of quarantine_dir to __USERS__
    my $quarantine_dir = EBox::Config::var() . '/lib/ebox/quarantine';
    EBox::Sudo::silentRoot("chown root:__USERS__ $quarantine_dir");
}


sub setSambaLdapToolsConf
{
    my ($self, %params) = @_;

    my $ldap = $self->ldap;

    my $netbios = exists $params{netbios} ? $params{netbios} : $self->netbios;
    my $domain = exists $params{domain} ? $params{domain} : $self->workgroup;
    my $sid;
    if (exists $params{sid}) {
        $sid = $params{sid};
    }
    else {
        my $sambaLdap = new EBox::SambaLdapUser;
        $sid = $sambaLdap->getSID();
    }

    my @array = ();
    push(@array, 'netbios'  => $netbios);
    push(@array, 'domain'   => $domain);
    push(@array, 'sid'	    => $sid);
    push(@array, 'ldap'     => $ldap->ldapConf());

    $self->writeConfFile(SMBLDAPTOOLCONFFILE, "samba/smbldap.conf.mas",
            \@array);

    @array = ();
    push(@array, 'password' => $ldap->getPassword());
    push(@array, 'ldap'     => $ldap->ldapConf());

    $self->writeConfFile(SMBLDAPTOOLBINDFILE,
            "samba/smbldap_bind.conf.mas", \@array,
            { mode => SMBLDAPTOOLBINDFILE_MASK,
            uid => SMBLDAPTOOLBINDFILE_UID,
            gid => SMBLDAPTOOLBINDFILE_GID });
}

sub _shareUsers {
    my $state = 0;

    my $pids = {};

    use File::Slurp;
    for my $line (`smbstatus`) {
        chomp($line);
        if($state == 0) {
            if($line =~ '----------------------------') {
                $state = 1;
            }
        } elsif($state == 1) {
            if($line eq '') {
                $state = 2;
            } else {
                # 1735  javi   javi     blackops  (192.168.45.48)
                $line =~ m/(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+\((\S+)\)/;
                my ($pid, $user, $machine) = ($1, $2, $4);
                $pids->{$pid} = { 'user' => $user, 'machine' => $machine };
            }
        } elsif($state == 2) {
            if($line =~ '----------------------------') {
                $state = 3;
            }
        } elsif($state == 3) {
            if($line eq '') {
                last;
            } else {
            #administracion   1735   blackops      Wed Nov 26 17:27:19 2008
                $line =~ m/(\S+)\s+(\d+)\s+(\S+)\s+(\S.+)/;
                my($share, $pid, $date) = ($1, $2, $4);
                $pids->{$pid}->{'share'} = $share;
                $pids->{$pid}->{'date'} = $date;
            }
        }
    }
    return [values %{$pids}];
}

sub _sharesGroupedBy
{
    my ($group) = @_;

    my $shareUsers = _shareUsers();

    my $groupedInfo = {};
    for my $info (@{$shareUsers}) {
        if(!defined($groupedInfo->{$info->{$group}})) {
            $groupedInfo->{$info->{$group}} = [];
        }
        push(@{$groupedInfo->{$info->{$group}}}, $info);
    }
    return $groupedInfo;
}

sub sharesByUserWidget
{
    my ($self, $widget) = @_;

    my $sharesByUser = _sharesGroupedBy('user');

    for my $user (sort keys %{$sharesByUser}) {
        my $section = new EBox::Dashboard::Section($user, $user);
        $widget->add($section);
        my $titles = [__('Share'), __('Source machine'), __('Connected since')];

        my $rows = {};
        foreach my $share (@{$sharesByUser->{$user}}) {
            my $id = $share->{'share'} . '_' . $share->{'machine'};
            $rows->{$id} = [$share->{'share'}, $share->{'machine'}, $share->{'date'}];
        }
        my $ids = [sort keys %{$rows}];
        $section->add(new EBox::Dashboard::List(undef, $titles, $ids, $rows));
    }
}

sub usersByShareWidget
{
    my ($self, $widget) = @_;

    my $usersByShare = _sharesGroupedBy('share');

    for my $share (sort keys %{$usersByShare}) {
        my $section = new EBox::Dashboard::Section($share, $share);
        $widget->add($section);
        my $titles = [__('User'), __('Source machine'), __('Connected since')];

        my $rows = {};
        foreach my $user (@{$usersByShare->{$share}}) {
            my $id = $user->{'user'} . '_' . $user->{'machine'};
            $rows->{$id} = [$user->{'user'}, $user->{'machine'}, $user->{'date'}];
        }
        my $ids = [sort keys %{$rows}];
        $section->add(new EBox::Dashboard::List(undef, $titles, $ids, $rows));
    }
}

# Method: widgets
#
#	Override EBox::Module::widgets
#
sub widgets
{
    return {
        'sharesbyuser' => {
            'title' => __('Shares by user'),
            'widget' => \&sharesByUserWidget,
            'order' => 7,
            'default' => 1
        },
        'usersbyshare' => {
            'title' => __('Users by share'),
            'widget' => \&usersByShareWidget,
            'order' => 9,
            'default' => 1
        }
    };
}

# Method: _daemons
#
#       Override EBox::Module::Service::_daemons
#
sub _daemons
{
    return [
        {
            'name' => 'nmbd',
        },
        {
            'name' => 'smbd',
        }
    ];
}

# Function: usesPort
#
#       Implements EBox::FirewallObserver interface
#
sub usesPort # (protocol, port, iface)
{
    my ($self, $protocol, $port, $iface) = @_;

    return undef unless($self->isEnabled());

    foreach my $smbport (SMBPORTS) {
        return 1 if ($port eq $smbport);
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

sub menu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('url' => 'Samba/Composite/General',
                                    'text' => $self->printableName(),
                                    'separator' => 'Office',
                                    'order' => 540));
}

#   Function: setPrinterService
#
#       Sets the printer sharing service through samba and cups
#
#   Parameters:
#
#       enabled - boolean. True enable, undef disable
#
sub setPrinterService # (enabled)
{
    my ($self, $active) = @_;
    ($active and $self->printerService) and return;
    (!$active and !$self->printerService) and return;

#	if ($active) {
#		if (not $self->fileService) {
#			my $fw = EBox::Global->modInstance('firewall');
#			foreach my $smbport (SMBPORTS) {
#				unless ($fw->availablePort('tcp',$smbport) and
#					$fw->availablePort('udp',$smbport)) {
#					throw EBox::Exceptions::DataExists(
#					'data'  => __('listening port'),
#					'value' => $smbport);
#				}
#			}
#		}
#	}
    $self->set_bool('printer_active', $active);
}

#   Method: servicePrinter
#
#       Returns if the printer sharing service is enabled
#
#   Returns:
#
#       boolean - true if enabled, otherwise undef
#
sub printerService
{
    my ($self) = @_;

    return $self->get_bool('printer_active');
}

#   Method: pdc
#
#       Returns if samba must configured as a PDC
#
#   Returns:
#
#       boolean - true if enabled, otherwise undef
#
sub pdc
{
    my ($self) = @_;

    my $model = $self->model('GeneralSettings');
    return $model->pdcValue();
}


#   Method: adminUser
#
#	Check if a given user is a Domain Administrator
#
#   Parameters:
#
#       user - string containign the username
#
#  Returns:
#
#       bool - true if it is, otherwise undef
#
sub  adminUser
{
    my ($self, $user) = @_;
    ($user) or return;
    my $usermod = EBox::Global->modInstance('users');


    my $isDomainAdmin  = $user eq any @{$usermod->usersInGroup('Domain Admins') };
    my $isAdministrator = $user eq any @{$usermod->usersInGroup('Administrators') };

    if ($isDomainAdmin and $isAdministrator) {
        return 1;
    }
    elsif ((not $isDomainAdmin) and (not $isAdministrator)) {
        return undef;
    }
    else {
        EBox::error("The user has incomplete group memberships; to be administrator he must be both member of domain Admins and Administrators group");
        return undef;
    }
}


#   Method: setAdminUser
#
#	Add a given user to the Domain Admins group
#
#   Parameters:
#
#       user - string containign the username
#	admin -  true if it must be an administrator, undef otherwise
#
#
sub  setAdminUser
{
    my ($self, $user, $admin) = @_;
    ($user) or return;
    ($admin xor $self->adminUser($user)) or return;
    my $usermod = EBox::Global->modInstance('users');
    if ($admin) {
        $usermod->addUserToGroup($user, 'Domain Admins');
        $usermod->addUserToGroup($user, 'Administrators');
    } else {
        $usermod->delUserFromGroup($user, 'Domain Admins');
        $usermod->delUserFromGroup($user, 'Administrators');
    }
}

#returns netbios name
sub netbios
{
    my ($self) = @_;

    my $model = $self->model('GeneralSettings');
    return $model->netbiosValue();
}

sub defaultNetbios
{
    my $hostname = Sys::Hostname::hostname();
    return substr($hostname, 0, MAXNETBIOSLENGTH);
}

sub roamingProfiles
{
    my ($self) = @_;

    my $model = $self->model('GeneralSettings');
    return $model->roamingValue();
}

#returns description name
sub description
{
    my ($self) = @_;

    my $desc = $self->model('GeneralSettings')->descriptionValue();
    return $desc;
}

#returns workgroup name
sub workgroup
{
    my ($self) = @_;

    my $model = $self->model('GeneralSettings');
    return $model->workgroupValue();
}

#returns userQuota name
sub defaultUserQuota
{
    my ($self) = @_;

    my $model = $self->model('GeneralSettings');

    my $value = $model->userquotaValue();
    if ($value eq 'userquota_disabled') {
        $value = 0;
    }

    return $value;
}

#returns drive letter
sub drive
{
    my ($self) = @_;

    my $model = $self->model('GeneralSettings');
    return $model->driveValue();
}

# LdapModule implmentation
sub _ldapModImplementation
{
    my $self;

    return new EBox::SambaLdapUser();
}

# Helper functions
sub _checkNetbiosName # (name)
{
    my ($name) = @_;

    (length($name) <= MAXNETBIOSLENGTH) or return undef;
    (length($name) > 0) or return undef;
    return 1;
}

sub _checkWorkgroupName # (name)
{
    my ($name) = @_;

    (length($name) <= MAXWORKGROUPLENGTH) or return undef;
    (length($name) > 0) or return undef;
    return 1;
}

sub _checkDescriptionName # (name)
{
    my ($name) = @_;

    (length($name) <= MAXDESCRIPTIONLENGTH) or return undef;
    (length($name) > 0) or return undef;
    return 1;
}

sub _checkQuota # (quota)
{
    my ($quota) = @_;

    ($quota =~ /\D/) and return undef;
    return 1;
}

sub _addPrinter
{
    my ($self, $name) = @_;

    $self->set_list("printers/$name/users", 'string', []);
    $self->set_list("printers/$name/groups", 'string', []);
    $self->set_bool("printers/$name/external", 1);
}

sub printers
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my %external;
    if ($global->modExists('printers')) {
        my $printers = $global->modInstance('printers');
        %external = map { $_ => 'new' } @{$printers->fetchExternalCUPSPrinters()};
    } else {
        return [];
    }

    my @printers;
    my $readOnly = $self->isReadOnly();
    for my $printer (@{$self->array_from_dir('printers')}) {
        my $name = $printer->{'_dir'};
        if (exists $external{$name}) {
            $external{$name} = 'exists';
        } else {
            $self->delPrinter($name) unless ($readOnly);
            $external{$name} = 'removed';
        }
        push (@printers,  $printer->{'_dir'});
    }

    unless ($readOnly) {
        for my $newPrinter (grep { $external{$_} eq 'new' } keys %external) {
            $self->_addPrinter($newPrinter);
            push (@printers, $newPrinter);
        }
    }

    return [sort @printers];
}

sub ignorePrinterNotFound
{
    my ($self) = @_;

    return $self->get_bool('ignorePrinterNotFound');
}

sub _printerNotFound
{
    my ($self, $printer) = @_;

    unless ($self->ignorePrinterNotFound()) {
        throw EBox::Exceptions::DataNotFound('data' => 'printer',
                'value' => $printer);
    }
}

sub _addUsersToPrinter # (printer, users)
{
    my ($self, $printer, $users) = @_;

    unless ($self->dir_exists("printers/$printer")) {
        $self->_printerNotFound($printer);
        return;
    }

    for my $username (@{$users}) {
        _checkUserExists($username);
    }

    $self->set_list("printers/$printer/users", "string", $users);
}

sub _addGroupsToPrinter # (printer, groups)
{
    my ($self, $printer, $groups) = @_;

    unless ($self->dir_exists("printers/$printer")) {
        $self->_printerNotFound($printer);
        return;
    }

    my $groupmod = EBox::Global->modInstance('users');

    my @existingGroups;
    for my $group (@{$groups}) {
        push (@existingGroups, $group) if ($groupmod->groupExists($group));
    }

    $self->set_list("printers/$printer/groups", "string", $groups);
}

sub _printerUsers # (printer)
{
    my ($self, $printer) = @_;

    unless ($self->dir_exists("printers/$printer")) {
        $self->_printerNotFound($printer);
        return [];
    }

    return $self->get_list("printers/$printer/users");
}

sub _printerGroups # (group)
{
    my ($self, $printer) = @_;

    unless ($self->dir_exists("printers/$printer")) {
        $self->_printerNotFound($printer);
        return [];
    }

    return $self->get_list("printers/$printer/groups");
}

sub _printersForUser # (user)
{
    my ($self, $user) = @_;

    my @printers;
    for my $name (@{$self->printers()}) {
        my $print = { 'name' => $name, 'allowed' => undef };
        my $users = $self->get_list("printers/$name/users");
        if (@{$users}) {
            $print->{'allowed'} = 1 if (grep(/^$user$/, @{$users}));
        }
        push (@printers, $print);
    }

    return \@printers;
}

sub _printersForGroup # (user)
{
    my ($self, $group) = @_;

    _checkGroupExists($group);

    my @printers;
    for my $name (@{$self->printers()}) {
        my $print = { 'name' => $name, 'allowed' => undef };
        my $groups = $self->get_list("printers/$name/groups");
        if (@{$groups}) {
            $print->{'allowed'} = 1 if (grep(/^$group$/, @{$groups}));
        }
        push (@printers, $print);
    }

    return \@printers;
}

sub setPrintersForUser # (user, printers)
{
    my ($self, $user, $newconf) = @_;

    my %currconf;
    for my $conf (@{$self->_printersForUser($user)}) {
        $currconf{$conf->{'name'}} = $conf->{'allowed'};
    }
    my @changes;
    for my $conf (@{$newconf}) {
        if ($currconf{$conf->{'name'}} xor $conf->{'allowed'}) {
            push (@changes, $conf);
        }
    }

    for my $printer (@changes) {
        my @users;
        my $new = undef;
        my $name = $printer->{'name'};
        if ($printer->{'allowed'}) {
            @users = @{$self->_printerUsers($name)};
            next if (grep(/^$user$/, @users));
            push (@users, $user);
            $new = 1;
        } else {
            my @ousers = @{$self->_printerUsers($name)};
            @users = grep (!/^$user$/, @ousers);
            if (@users != @ousers) {
                $new = 1;
            }
        }

        $self->_addUsersToPrinter($name, \@users) if ($new);
    }
}

sub setPrintersForGroup # (user, printers)
{
    my ($self, $group, $newconf) = @_;

    _checkGroupExists($group);

    my %currconf;
    for my $conf (@{$self->_printersForGroup($group)}) {
        $currconf{$conf->{'name'}} = $conf->{'allowed'};
    }
    my @changes;
    for my $conf (@{$newconf}) {
        if ($currconf{$conf->{'name'}} xor $conf->{'allowed'}) {
            push (@changes, $conf);
        }
    }

    for my $printer (@changes) {
        my @groups;
        my $new = undef;
        my $name = $printer->{'name'};
        if ($printer->{'allowed'}) {
            @groups = @{$self->_printerGroups($name)};
            next if (grep(/^$group$/, @groups));
            push (@groups, $group);
            $new = 1;
        } else {
            my @ogroups = @{$self->_printerGroups($name)};
            @groups = grep (!/^$group$/, @ogroups);
            if (@groups != @ogroups) {
                $new = 1;
            }
        }

        $self->_addGroupsToPrinter($name, \@groups) if ($new);
    }
}

sub delPrinter # (resource)
{
    my ($self, $name) = @_;

    unless ($self->dir_exists("printers/$name")) {
        throw EBox::Exceptions::DataNotFound('data' => 'printer',
                'value' => $name);
    }

    $self->delete_dir("printers/$name");
}

sub existsShareResource # (resource)
{
    my ($self, $name) = @_;

    my $usermod = EBox::Global->modInstance('users');
    if ($usermod->configured()) {
        if ($usermod->userExists($name)) {
            return __('user');
        }

        if ($usermod->groupExists($name)) {
            return __('group');
        }
    }

    for my $printer (@{$self->printers()}) {
        return __('printer') if ($name eq $printer);
    }

    return undef;
}

sub _checkUserExists # (user)
{
    my ($user) = @_;

    my $usermod = EBox::Global->modInstance('users');
    unless ($usermod->userExists($user)){
        throw EBox::Exceptions::DataNotFound(
                'data'  => __('user'),
                'value' => $user);
    }

    return 1;
}

sub _checkGroupExists # (user)
{
    my ($group) = @_;

    my $groupmod = EBox::Global->modInstance('users');
    unless ($groupmod->groupExists($group)){
        throw EBox::Exceptions::DataNotFound(
                'data'  => __('group'),
                'value' => $group);
    }

    return 1;
}

sub _sambaPrinterConf
{
    my ($self) = @_;

    my @printers;
    foreach my $printer (@{$self->printers()}) {
        my $users = "";
        for my $user (@{$self->_printerUsers($printer)}) {
            $users .= "\"$user\" ";
        }
        for my $group (@{$self->_printerGroups($printer)}) {
            $users .= "\@\"$group\" ";
        }
        push (@printers, { 'name' => $printer , 'users' => $users});
    }

    return \@printers;
}

sub enableQuota
{
    return (EBox::Config::configkey('enable_quota') eq 'yes');
}

# Method: currentUserQuota
#
#	Fetch the current set quota for a given user
#
# Parameters:
#
#	user - string
#
# Returns:
#
#	Integer - quota in MB. 0 means no quota
#
sub currentUserQuota
{
    my ($self, $user) = @_;

    my $usermod = EBox::Global->modInstance('users');
    unless (defined($user) and $usermod->uidExists($user)) {
        throw EBox::Exceptions::External("user is not valid");
    }
    my @quotaValues = @{EBox::Sudo::root(QUOTA_PROGRAM . " -q $user ")};

    return $quotaValues[0];
}

# Method: setUserQuota
#
#	Set user quota
#
# Parameters:
#
#	Quota - Integer. Quota in MB. 0 no quota.
#
# Returns:
#
#	Integer - quota in MB. 0 means no quota
#
sub setUserQuota
{
    my ($self, $user, $userQuota) = @_;

    return unless ($self->enableQuota());

    my $usermod = EBox::Global->modInstance('users');
    unless (defined($user) and $usermod->uidExists($user)) {
        throw EBox::Exceptions::External("user is not valid");
    }

    unless (_checkQuota($userQuota)) {
        throw EBox::Exceptions::InvalidData
            ('data' => __('quota'), 'value' => $userQuota);
    }

    my $quota = $userQuota * 1024;

    EBox::Sudo::root(QUOTA_PROGRAM . " -s $user $quota");
}

sub dumpConfig
{
    my ($self, $dir) = @_;

    $self->_dumpSharesTree($dir);
}

sub restoreConfig
{
    my ($self, $dir) = @_;

    $self->set_bool('ignorePrinterNotFound', 1);

    try {
        $self->_loadSharesTree($dir);
        $self->fixSIDs();

        my $sambaLdapUser = new EBox::SambaLdapUser;
        $sambaLdapUser->migrateUsers();
    } finally {
        $self->set_bool('ignorePrinterNotFound', 0);
    }
}

sub restoreDependencies
{
    my @depends = ();

    push(@depends, 'users');

    if ( EBox::Global->modExists('printers') )  {
        push(@depends, 'printers');
    }

    return \@depends;
}


# backup domains

sub backupDomains
{
    my $name = 'shares';
    my %attrs  = (
                  printableName => __('File Sharing'),
                  description   => __(q{Shares, users and groups homes and profiles}),
                 );

    return ($name, \%attrs);
}

sub backupDomainsFileSelection
{
    my ($self, %enabled) = @_;
    if ($enabled{shares}) {
        my $sambaLdapUser = new EBox::SambaLdapUser();
        my @dirs =  @{ $sambaLdapUser->sharedDirectories() };
        push @dirs, map {
            $_->{path}
        } @{ $self->shares(1) };

        my $selection = {
                          includes => \@dirs,
                         };
        return $selection;
    }

    return {};
}

sub _dumpSharesTree
{
    my ($self, $dir) = @_;

    my $sambaLdapUser = new EBox::SambaLdapUser;
    my @shares = map {
        my $share = $_;
        my ($uid, $gid, $permissions);
        if (defined $share) {
            my $stat = EBox::Sudo::stat($share);
            if (defined $stat) {
                $permissions = EBox::FileSystem::permissionsFromStat($stat) ;
                $uid = $stat->uid;
                $gid = $stat->gid;
            }
            else {
                EBox::warn("Cannot stat directory $share. This directory will be ignored");
            }
        }
        (defined $share) and (defined $permissions) ? "$share:$uid:$gid:$permissions" : ();
    } @{ $sambaLdapUser->sharedDirectories() };


    my $sharesTreeData = join "\n",  @shares;
    write_file($self->_sharesTreeFile($dir), $sharesTreeData);
}

sub _loadSharesTree
{
    my ($self, $dir) = @_;

    my $contents = read_file($self->_sharesTreeFile($dir));

    my @shares = split "\n", $contents;

    if (not @shares) {
        # maybe the file is in the old format. It will have problems with spaces
        # in directory names
        @shares = split '\s+', $contents;
    }

    my @commands;
    foreach my $dirInfo (@shares) {
        my ($dir, $uid, $gid, $perm) = split ':', $dirInfo;

        unless (-d $dir) {
            push (@commands, "mkdir -p  '$dir'");
        }

        push (@commands, "chmod $perm '$dir'"); # restore permissions
        push (@commands, "chown $uid:$gid '$dir'");
    }
    EBox::Sudo::root(@commands);
}

sub fixSIDs
{
    my ($self)  = @_;

    # we use  the SID of the 'Domain Admins' standard group to extract the domain
    # SID portion
    my $sambaLdapUser   = new EBox::SambaLdapUser;

    my $domainSid = _sidFromLdap();

    if (not $sambaLdapUser->checkDomainSID($domainSid)) {
    # for first time..
    # XXX this must be more elegant!
    #    print "NOT DEFINED\n";
        $domainSid = $sambaLdapUser->alwaysGetSID;
    }


    #  print "DSID $domainSid\n";

    my $cmd = FIX_SID_PROGRAM . ' ' . $domainSid;
    EBox::Sudo::root($cmd);
}

# get the sid from a ldap entry (currrently it uses the Domain Admins SID's
# group bz it not garanteed the sambaDomain object exists)
sub _sidFromLdap
{
    my ($self) = @_;

    my $sambaLdapUser   = new EBox::SambaLdapUser;
    my $domainSid;

    try {
        my $domainAdminsSid = $sambaLdapUser->getGroupSID('Domain Admins');
#   print "domainAdminsSid $domainAdminsSid\n";
        if ($domainAdminsSid) {
            $domainSid = $domainAdminsSid;
            $domainSid =~ s/-\d+?$//;
        }

    }
    otherwise {
        $domainSid = undef;
    };

    return $domainSid;
}


# sets the sID using the net tool
sub setNetSID
{
    my ($self, $sid) = @_;

    $self->_setNetDomainSID($sid);
    $self->_setNetLocalSID($sid);
}

sub _setNetLocalSID
{
    my ($self, $domainSID) = @_;
    my $cmd = "net  SETLOCALSID $domainSID";
    EBox::Sudo::root($cmd);
}


sub _setNetDomainSID
{
    my ($self, $domainSID) = @_;
    my $cmd = "net  SETDOMAINSID $domainSID";
    EBox::Sudo::root($cmd);
}



sub _sharesTreeFile
{
    my ($self, $dir) = @_;
    return "$dir/sharesTree.bak";
}



# Overrides:
#   EBox::Report::DiskUsageProvider::_facilitiesForDiskUsage
sub _facilitiesForDiskUsage
{
    my ($self) = @_;

    my $usersPrintableName  = __(q{Users files});
    my $usersPath           = EBox::SambaLdapUser::usersPath();
    my $groupsPrintableName = __(q{Groups files});
    my $groupsPath          = EBox::SambaLdapUser::groupsPath();

    return {
        $usersPrintableName   => [ $usersPath ],
        $groupsPrintableName  => [ $groupsPath ],
    };
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
    my @access_order = qw(timestamp client username event resource);;
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
        'index' => 'samba_access',
        'titles' => $access_titles,
        'order' => \@access_order,
        'tablename' => 'samba_access',
        'timecol' => 'timestamp',
        'filter' => ['client', 'username', 'resource'],
        'events' => $access_events,
        'eventcol' => 'event'
    },
    {
        'name' => __('Samba virus'),
        'index' => 'samba_virus',
        'titles' => $virus_titles,
        'order' => \@virus_order,
        'tablename' => 'samba_virus',
        'timecol' => 'timestamp',
        'filter' => ['client', 'filename', 'virus'],
        'events' => $virus_events,
        'eventcol' => 'event'
    },
    {
        'name' => __('Samba quarantine'),
        'index' => 'samba_quarantine',
        'titles' => $quarantine_titles,
        'order' => \@quarantine_order,
        'tablename' => 'samba_quarantine',
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

sub isAntivirusPresent
{

    my $global = EBox::Global->getInstance();

    return ($global->modExists('antivirus')
             and (-f '/usr/lib/samba/vfs/vscan-clamav.so'));
}







sub report
{
    my ($self, $beg, $end, $options) = @_;
    my $maxTopActivityUsers = $options->{'max_top_activity_users'};
    my $maxTopActivityGroups =  $options->{'max_top_activity_groups'};
    my $maxTopSizeShares =  $options->{'max_top_size_shares'};
    my $maxTopVirusShares =  $options->{'max_top_virus_shares'};

    my $report = {};

    $report->{'activity'} = $self->runMonthlyQuery($beg, $end, {
        'select' => 'COALESCE(SUM(operations), 0) AS OPERATIONS',
        'from' => 'samba_access_report'
    });

    $report->{'top_activity_users'} = $self->runQuery($beg, $end, {
        'select' => 'username, SUM(operations) AS operations',
        'from' => 'samba_access_report',
        'group' => 'username',
        'limit' => $maxTopActivityUsers,
        'order' => 'operations DESC'
    });


    $report->{top_activity_groups} = _topActivityGroups($self, $beg, $end, $maxTopActivityGroups);

    $report->{'top_size_shares'} = $self->runQuery($beg, $end, {
        'select' => 'share, type, AVG(size) AS size',
        'from' => 'samba_disk_usage_report',
        'group' => 'share, type',
        'limit' => $maxTopSizeShares,
        'order' => 'size DESC',
    });

    $report->{'top_size_user_shares'} = $self->runQuery($beg, $end, {
        'select' => 'share, AVG(size) AS size',
        'from' => 'samba_disk_usage_report',
        'group' => 'share',
        'limit' => $maxTopSizeShares,
        'order' => 'size DESC',
        'where' => q{type = 'user'}
    });

    $report->{'top_size_group_shares'} = $self->runQuery($beg, $end, {
        'select' => 'share, AVG(size) AS size',
        'from' => 'samba_disk_usage_report',
        'group' => 'share, type',
        'limit' => $maxTopSizeShares,
        'order' => 'size DESC',
        'where' => q{type = 'group'}
    });

    $report->{'top_size_custom_shares'} = $self->runQuery($beg, $end, {
        'select' => 'share, AVG(size) AS size',
        'from' => 'samba_disk_usage_report',
        'group' => 'share, type',
        'limit' => $maxTopSizeShares,
        'order' => 'size DESC',
        'where' => q{type = 'custom'}
    });

    $report->{'top_virus_shares'} = $self->runQuery($beg, $end, {
        'select' => 'share, SUM(virus) as virus',
        'from' => 'samba_virus_share_report',
        'group' => 'share',
        'limit' => $maxTopVirusShares,
        'order' => 'virus DESC',
    });


    return $report;
}


sub _topActivityGroups
{
    my ($self, $beg, $end, $maxTopActivityGroups) = @_;
    my $usersMod = EBox::Global->modInstance('users');

    my $sqlResult = $self->runQuery($beg, $end, {
        'select' => 'username, SUM(operations) AS operations',
        'from' => 'samba_access_report',
        'group' => 'username',
    });
    my %operationsByUser;
    foreach my $i (0 .. $#{ $sqlResult->{username} } ) {
        $operationsByUser{ $sqlResult->{username}->[$i] } =  $sqlResult->{operations}->[$i];
    }

    delete $sqlResult->{username};
    delete $sqlResult->{operations};


    my $min = -1;
    my @groupsAndOperations;
    foreach my $group_r ($usersMod->groups()) {
        my $groupname = $group_r->{account};
        my $operations = 0;

        my @users = @{ $usersMod->usersInGroup($groupname) };
        foreach my $user (@users) {
            $operations += $operationsByUser{$user};
        }


        if (@groupsAndOperations <   $maxTopActivityGroups ) {
            push @groupsAndOperations, [$groupname => $operations];
        } elsif ($operations > $min) {
            pop @groupsAndOperations;
            push @groupsAndOperations, [$groupname => $operations];
        } else {
            next;
        }

        @groupsAndOperations = sort { $b->[1] <=> $a->[1]  } @groupsAndOperations;
        $min = $groupsAndOperations[-1]->[1];
    }

    my @topGroups     = map { $_->[0]  } @groupsAndOperations;
    my @topOperations = map { $_->[1] } @groupsAndOperations;
    return {
            'groupname' => \@topGroups,
            'operations' => \@topOperations,
           };
}

sub consolidateReportQueries
{
    return [
        {
            'target_table' => 'samba_access_report',
            'query' => {
                'select' => 'username, COUNT(event) AS operations',
                'from' => 'samba_access',
                'group' => 'username'
            }
        },
        {
            'target_table' => 'samba_virus_report',
            'query' => {
                'select' => 'client, COUNT(event) AS virus',
                'from' => 'samba_virus',
                'group' => 'client'
            }
        },
        {
            'target_table' => 'samba_disk_usage_report',
            'query' => {
                'select' => 'share, type, CAST (AVG(size) AS int) AS size',
                'from' => 'samba_disk_usage',
                'group' => 'share, type'

            },
        },
        {
            'target_table' => 'samba_virus_share_report',
            'query' => {
                'select' => 'share, count(*) as virus',
                'from' => 'samba_quarantine',
                'where' => q{event='quarantine'},
                'group' => 'filename'
            },
            'rowConversor' => \&_virusShareReportRowConversor,
            'targetGroupFields' => ['share'],
        },
    ];
}





my @sharesSortedByPathLen;

sub _updatePathsByLen
{
    my ($self) = @_;

    my $ldapInfo = EBox::SambaLdapUser->new();
    @sharesSortedByPathLen = map {
         { path => $_->{path},
           share => $_->{sharename} }
    } ( @{ $ldapInfo->userShareDirectories },
        @{ $ldapInfo->groupShareDirectories }
      );

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

sub _shareByFilename
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


sub _virusShareReportRowConversor
{
    my ($row) = @_;
    my $filename = delete $row->{filename};
    my $share = _shareByFilename($filename);
    EBox::debug("COBV $filename -> $share");
    if ($share) {
        $row->{share} = $share;
    } else {
        return undef;
    }


    return $row;
}


sub logReportInfo
{
    my ($self) = @_;

    if ($self->_diskUsageAlreadyCheckedToday) {
        return [];
    }

    my @reportData;

    my %shareByPath;

    my @shares = @{ $self->_sharesAndSizes() };


    foreach my $share (@shares) {
        # add info about disk usage by share
        my $entry = {
                     table => 'samba_disk_usage',
                     values => {
                                share => $share->{share},
                                size  => $share->{size},
                                type  => $share->{type},
                               }
                    };
        push @reportData, $entry;
    }

    return \@reportData;
}


sub _diskUsageAlreadyCheckedToday
{
    my ($self) = @_;

    my $db = EBox::DBEngineFactory::DBEngine();
    my $query = q{SELECT share FROM samba_disk_usage WHERE (timestamp >= (current_date + interval '0 day')) AND (timestamp < (current_date + interval '1 day'))};
    my $results = $db->query($query);
    return @{ $results } > 0;
}

sub _sharesAndSizes
{
    my ($self) = @_;

    my $ldapInfo = EBox::SambaLdapUser->new();
    my @shares;

    foreach my $sh_r ( @{  $ldapInfo->userShareDirectories }) {
        my $share = {
                     share => $sh_r->{sharename},
                     path  => $sh_r->{path},
                     type  => 'user',
                    };
        push @shares, $share;
    }

    foreach my $sh_r ( @{  $ldapInfo->groupShareDirectories }) {
        my $share = {
                     share => $sh_r->{sharename},
                     path  => $sh_r->{path},
                     type  => 'group',
                    };
        push @shares, $share;
    }



    # add no-account shares to share list
    foreach my $sh_r (@{ $self->shares(1)  }) {
        my $share = {
                     share => $sh_r->{share},
                     path  => $sh_r->{path},
                     type  => 'custom',
                    };
        push @shares, $share;
    }


    foreach my $share (@shares) {
        my $path = $share->{path};
        if (EBox::Sudo::fileTest('-d', $path)) {
            my $output = EBox::Sudo::rootWithoutException("du -ms '$path'");

            my ($size) =  $output->[0] =~ m{^(\d+)};
            if (not defined $size) {
                EBox::error("Problem getting $path size: @{$output}");
                $size = 0;
            }

            $share->{size} = $size;
        }
    }


    return \@shares;
}


1;
