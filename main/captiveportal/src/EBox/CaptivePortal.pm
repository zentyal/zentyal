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

package EBox::CaptivePortal;

use base qw(EBox::Module::Service
            EBox::FirewallObserver
            EBox::Events::WatcherProvider
          );

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Menu::Item;
use TryCatch::Lite;
use EBox::Sudo;
use EBox::CaptivePortal::Middleware::AuthFile;
use EBox::CaptivePortalFirewall;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;

use constant CAPTIVE_DIR => '/var/lib/zentyal-captiveportal/';
use constant SIDS_DIR => CAPTIVE_DIR . 'sessions/';
use constant LOGOUT_FILE => CAPTIVE_DIR . 'logout';
use constant PERIOD_FILE => CAPTIVE_DIR . 'period';
use constant CAPTIVE_USER  => 'zentyal-captiveportal';
use constant CAPTIVE_GROUP => 'zentyal-captiveportal';
use constant CAPTIVE_UPSTART_NAME => 'zentyal.captiveportal-uwsgi';
use constant CAPTIVE_NGINX_FILE => CAPTIVE_DIR . 'captiveportal-nginx.conf';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(
        name          => 'captiveportal',
        printableName => __('Captive Portal'),
        @_
    );

    bless($self, $class);
    return $self;
}

# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('url' => 'CaptivePortal/Composite/General',
                                    'icon' => 'captiveportal',
                                    'text' => $self->printableName(),
                                    'separator' => 'Gateway',
                                    'order' => 226));
}

# Method: _setConf
#
#  Override <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    my $permissions = {
        uid => 0,
        gid => 0,
        mode => '0644',
        force => 1,
    };
    my $socketPath = '/run/zentyal-' . $self->name();
    my $socketName = 'captiveportal.sock';
    my $upstartFileTemplate = 'core/upstart-uwsgi.mas';
    my $upstartFile = '/etc/init/' . CAPTIVE_UPSTART_NAME . '.conf';
    my @confFileParams = ();
    push (@confFileParams, socketpath => $socketPath);
    push (@confFileParams, socketname => $socketName);
    push (@confFileParams, script => EBox::Config::psgi() . 'captiveportal.psgi');
    push (@confFileParams, module => $self->printableName());
    push (@confFileParams, user   => CAPTIVE_USER);
    push (@confFileParams, group  => CAPTIVE_GROUP);
    EBox::Module::Base::writeConfFileNoCheck(
        $upstartFile, $upstartFileTemplate, \@confFileParams, $permissions);

    my $nginxFileTemplate = 'captiveportal/nginx.conf.mas';
    @confFileParams = ();
    push (@confFileParams, socket   => "$socketPath/$socketName");
    push (@confFileParams, port     => $self->httpPort());
    push (@confFileParams, sslport  => $self->httpsPort());
    push (@confFileParams, confdir  => CAPTIVE_DIR);
    EBox::Module::Base::writeConfFileNoCheck(
        CAPTIVE_NGINX_FILE, $nginxFileTemplate, \@confFileParams, $permissions);

    my $webadminMod = $self->global()->modInstance('webadmin');
    $webadminMod->addNginxServer(CAPTIVE_NGINX_FILE);

    my $settings = $self->model('Settings');

    # Write css file
    $self->_writeCSS();

    $self->_writePeriodFile();
}

sub _writeCSS
{
    my ($self) = @_;

    my $path = EBox::Config::dynamicwww() . '/css';
    unless (-d $path) {
        mkdir $path;
    }

    my $global = EBox::Global->getInstance();
    my $theme = $global->theme();
    my %params = %{ $theme };

    EBox::Module::Base::writeConfFileNoCheck("$path/captiveportal.css",
                                             "css/captiveportal.css.mas",
                                             [ %params ],
                                             { mode => '0644' });
}

# Method: _daemons
#
#  Override <EBox::Module::Service::_daemons>
#
sub _daemons
{
    my ($self) = @_;

    return [
        {
            name => CAPTIVE_UPSTART_NAME
        },
        {
            name => 'zentyal.captived'
        },
    ];
}

# Method: widgets
#
#   Returns the widgets offered by this module
#
# Overrides:
#
#       <EBox::Module::widgets>
#
#sub widgets
#{
#}

sub firewallHelper
{
    my ($self) = @_;

    if ($self->isEnabled()) {
        return new EBox::CaptivePortalFirewall();
    }
    return undef;
}

# Function: usesPort
#
#   Implements EBox::FirewallObserver interface
#
sub usesPort # (protocol, port, iface)
{
    my ($self, $protocol, $port, $iface) = @_;

    unless ($protocol eq 'tcp') {
        return undef;
    }
    unless ($self->isEnabled()) {
        return undef;
    }

    if ($port eq $self->httpPort()) {
        return 1;
    }
    if ($port eq $self->httpsPort()) {
        return 1;
    }

    return undef;
}

# Function: httpPort
#
#   Returns the port where captive portal HTTP redirection resides
#
sub httpPort
{
    my ($self) = @_;
    my $settings = $self->model('Settings');
    return $settings->http_portValue(),
}

# Function: httpsPort
#
#   Returns the port where captive portal resides
#
sub httpsPort
{
    my ($self) = @_;
    my $settings = $self->model('Settings');
    return $settings->https_portValue(),
}

sub expirationTime
{
    my ($self) = @_;
    my $settings = $self->model('Settings');
    return $settings->expirationValue(),
}

# Function: ifaces
#
#   Interfaces where captive portal is enabled
#
sub ifaces
{
    my ($self) = @_;
    my $model = $self->model('Interfaces');
    my $ids = $model->ids();
    my @ifaces;
    for my $id (@{$ids}) {
        my $row = $model->row($id);
        if($row->valueByName('enabled')) {
            push(@ifaces, $row->valueByName('interface'));
        }
    }
    return \@ifaces;
}

# Session manage methods:

# Function: sessionExpired
#
#   returns 1 if the session has expired
#
# Parameters:
#   time - session time value
#
sub sessionExpired
{
    my ($self, $time) = @_;

    return time() > ($time + $self->expirationTime() + 30);
}

# Function: currentUsers
#
#   Current logged in users array:
#
# Returns:
#
#   Array ref with this layout:
#
#   [
#      {
#          user => 'username',
#          ip   => 'X.X.X.X',
#          mac  => 'XX:XX:XX:XX:XX:XX', (optional, if known)
#          sid  => 'session id',
#          time => X,                   (last session update timestamp)
#          quotaExtension => X,
#          bwusage => X,
#      },
#      ...
#   ]
sub currentUsers
{
    my ($self) = @_;
    my $model = $self->model('Users');
    return $model->currentUsers();
}

sub currentSidsByFWRules
{
    my %users;
# It is assumed that captiveportal user rules are always RETURN and has only the
# variable fields assigned in the below regex
# Also it is assumed that it is only one rule by session
# Example: 0 0 RETURN all -- * * 192.168.56.5 0.0.0.0/0 MAC 00:0C:29:E7:71:B8 /*u1:d128a0371046a523c8eb4ad79206de38 */

    foreach my $tableAndChain (['nat', 'captive'], ['filter', 'icaptive'], ['filter', 'fcaptive']) {
        my ($table, $chain) = @{ $tableAndChain };
        my $rules = EBox::Sudo::root("iptables -t $table -vL $chain -n");
        foreach my $rule (@{$rules}) {
            $rule =~ m{
                          ([\d.]+)\s+                # source field $1
                          [\d./]+\s+                 # destination field (not used)
                          MAC\s+([:A-F0-9]+)\s+      # MAC field $2
                          /\*\s*(.*?):(.*?)\s*\*/\s* # commentary field (user:sid) $3 $4
                          $
                  }msx;
            if ($1 and $2 and $3 and $4) {
                if (not exists $users{$4}) {
                    $users{$4} = {};
                }
                $users{$4}->{$chain} = {
                    user => $3,
                    ip   => $1,
                    mac  => $2,
                };
            }
        }
    }

    return \%users;
}

# method: userFirewallRule
#
#   Parameters:
#     - User session data
#
#   Returns:
#     - Iptables rule part with matching and decision (RETURN);
sub userFirewallRule
{
    my ($self, $user, $sid) = @_;

    my $ip = $user->{ip};
    my $name = $user->{user};
    my $mac = $user->{mac};
    my $macSrc = '';
    $macSrc = "-m mac --mac-source $mac" if defined($mac);
    return "-s $ip $macSrc -m comment --comment '$name:$sid' -j RETURN";
}

sub exceptionsFirewallRules
{
    my ($self, $chain) = @_;
    my @rules;

    my $exceptionsModel = $self->model('Exceptions');
    push @rules, @{ $exceptionsModel->firewallRules($chain) };

    my $global = $self->global();
    foreach my $mod (@{ $global->modInstances()}) {
        if ($mod->can('firewallCaptivePortalExceptions')) {
            push @rules, @{ $mod->firewallCaptivePortalExceptions($chain)  };
        }
    }

    return \@rules;
}

# Function: quotaExceeded
#
#   returns 1 if user has exceeded his quota
#
# Parameters:
#   - username
#   - bwusage, bandwidth usage in MB
#
sub quotaExceeded
{
    my ($self, $username, $bwusage, $extension) = @_;

    my $model = $self->model('BWSettings');
    unless ($model->limitBWValue()) {
        # Quotas disabled, no limit:
        return 0;
    }
    my $quota = $self->userQuota($username);

    # No limit
    return 0 if ($quota == 0);

    $quota += $extension;

    # check quota
    return $bwusage > $quota;
}

sub _writePeriodFile
{
    my ($self) = @_;
    my $period = $self->expirationTime();
    EBox::Module::Base::writeFile(PERIOD_FILE,
                                  "$period",
                                  {
                                      mode => '0600',
                                      uid  => CAPTIVE_USER,
                                      gid  => CAPTIVE_GROUP,
                                  }
                                 );

}

sub _bwmonitor {
    my $bwmonitor = EBox::Global->modInstance('bwmonitor');
    return defined($bwmonitor) and $bwmonitor->isEnabled();
}

sub eventWatchers
{
    return ['CaptivePortalQuota'];
}

# Method: addUser
#
#   Adds a user to the captive portal users file.
#
# Parameters:
#
#   - username - String the username to add.
#   - password - String the password to validate the given username.
#   - fullname - String the fullname of the user.
#   - quota    - Integer monthly bandwidth usage quota or undef to use the default.
#
# Throws:
#   <EBox::Exceptions::MissingArgument> if username or password arguments are not defined
#   <EBox::Exceptions::DataExists> if the username already exists
#   <EBox::Exceptions::InvalidData> if the quota is not an integer
#
sub addUser
{
    my ($self, $username, $password, $fullname, $quota) = @_;

    unless ($username) {
        throw EBox::Exceptions::MissingArgument('username');
    }
    unless ($password) {
        throw EBox::Exceptions::MissingArgument('password');
    }

    if ($quota) {
        unless ($quota =~ /^\d+$/) {
            throw EBox::Exceptions::InvalidData(
                data => 'quota', value => $quota, advice => __('Quota must be an integer'));
        }
    }

    my $users = EBox::CaptivePortal::Middleware::AuthFile::allUsersFromFile();
    if (exists $users->{$username}) {
        throw EBox::Exceptions::DataExists(data => 'username', value => $username);
    }

    my $hash = EBox::CaptivePortal::Middleware::AuthFile::hashPassword($password);
    $users->{$username} = { fullname => $fullname, quota => $quota, hash => $hash };
    EBox::CaptivePortal::Middleware::AuthFile::writeUsersFile($users);
}

# Method: listUsers
#
#   Lists the valid usernames that will be allowed to use the captive portal.
#
# Returns:
#   Hash reference with this format:
#
#   {
#       'usernameWithCustomQuota' => {
#           quota    => 10240,
#       },
#       'usernameWithDefaultQuota' => {
#           fullname => 'Foo Bar',
#       },
#       ...
#   }
#
sub listUsers
{
    my ($self) = @_;

    my $users = EBox::CaptivePortal::Middleware::AuthFile::allUsersFromFile();

    my $list = {};
    foreach my $user (keys %{$users}) {
        my $userHash = {};
        $userHash->{fullname} = $users->{$user}->{fullname} if (exists $users->{$user}->{fullname});
        $userHash->{quota} = $users->{$user}->{quota} if (exists $users->{$user}->{quota});
        $list->{$user} = $userHash;
    }
    return $list;
}

# Method: modifyUser
#
#   Modifies user parameters on the captive portal users file
#
# Parameters:
#
#   - username - String the username to modify.
#   - args     - Hash dictionary (missing args are not changed):
#       - password - String the new password to validate the given username (optional).
#       - fullname - String the new fullname for the user (optional).
#       - quota    - Integer monthly bandwidth usage quota or undef to use the default.
#
# Throws:
#   <EBox::Exceptions::MissingArgument> if username argument is not defined.
#   <EBox::Exceptions::DataNotFound> if the given username doesn't exist.
#
sub modifyUser
{
    my ($self, $username, %args) = @_;

    unless ($username) {
        throw EBox::Exceptions::MissingArgument('username');
    }

    my $users = EBox::CaptivePortal::Middleware::AuthFile::allUsersFromFile();

    my $user = $users->{$username};
    unless (defined $user) {
        throw EBox::Exceptions::DataNotFound(data => 'username', value => $username);
    }

    $user->{fullname} = $args{fullname} if (exists $args{fullname});
    $user->{quota} = $args{quota} if (exists $args{quota});
    $user->{hash} = EBox::CaptivePortal::Middleware::AuthFile::hashPassword($args{password}) if (exists $args{password});

    EBox::CaptivePortal::Middleware::AuthFile::writeUsersFile($users);
}

# Method: removeUser
#
#   Removes a user from the captive portal users file
#
# Parameters:
#
#   - username - String the username to remove.
#
# Throws:
#   <EBox::Exceptions::MissingArgument> if username argument is not defined.
#   <EBox::Exceptions::DataNotFound> if the given username doesn't exist.
#
sub removeUser
{
    my ($self, $username) = @_;

    unless ($username) {
        throw EBox::Exceptions::MissingArgument('username');
    }

    my $users = EBox::CaptivePortal::Middleware::AuthFile::allUsersFromFile();

    if (defined $users->{$username}) {
        delete $users->{$username};
    } else {
        throw EBox::Exceptions::DataNotFound(data => 'username', value => $username);
    }

    EBox::CaptivePortal::Middleware::AuthFile::writeUsersFile($users);
}

# Method: userQuota
#
#   Gets the given user bandwidth quota.
#
# Parameters:
#
#   - username - String the username to get the quota for.
#
# Returns:
#
#   Integer the quota for the given username.
#
# Throws:
#   <EBox::Exceptions::MissingArgument> if username argument is not defined.
#   <EBox::Exceptions::DataNotFound> if the given username doesn't exist.
#
sub userQuota
{
    my ($self, $username) = @_;

    unless ($username) {
        throw EBox::Exceptions::MissingArgument('username');
    }

    my $user = EBox::CaptivePortal::Middleware::AuthFile::userFromFile($username);

    if ($user) {
        my $model = $self->model('BWSettings');
        my $defaultQuota = $model->defaultQuotaValue();

        return (defined $user->{quota}) ? $user->{quota} : $defaultQuota;
    } else {
        throw EBox::Exceptions::DataNotFound(data => 'username', value => $username);
    }
}

1;
