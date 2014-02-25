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
            EBox::LdapModule
            EBox::Events::WatcherProvider
          );

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Menu::Item;
use Error qw(:try);
use EBox::Sudo;
use EBox::Ldap;
use EBox::CaptivePortalFirewall;
use EBox::CaptivePortal::LdapUser;
use EBox::Exceptions::External;

use constant CAPTIVE_DIR => '/var/lib/zentyal-captiveportal/';
use constant SIDS_DIR => CAPTIVE_DIR . 'sessions/';
use constant LOGOUT_FILE => CAPTIVE_DIR . 'logout';
use constant APACHE_CONF => CAPTIVE_DIR . 'apache2.conf';
use constant LDAP_CONF => CAPTIVE_DIR . 'ldap.conf';
use constant PERIOD_FILE => CAPTIVE_DIR . 'period';
use constant CAPTIVE_USER  => 'zentyal-captiveportal';
use constant CAPTIVE_GROUP => 'zentyal-captiveportal';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'captiveportal',
                                      printableName => __('Captive Portal'),
                                      @_);

    $self->{cpldap} = new EBox::CaptivePortal::LdapUser();

    bless($self, $class);
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
            'action' => __('Add LDAP schemas'),
            'reason' => __('Zentyal will use this schema to store user sessions info.'),
            'module' => 'captiveportal'
        },
    ];
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

# Method: enableActions
#
#       Override EBox::Module::Service::enableActions
#
sub enableActions
{
    my ($self) = @_;

    $self->performLDAPActions();

    # Execute enable-module script
    $self->SUPER::enableActions();
}

sub _setConf
{
    my ($self) = @_;
    my $settings = $self->model('Settings');
    my $sldap = $self->model('SecondaryLDAP');
    my $usersMod = EBox::Global->modInstance('users');


    # Apache conf file
    EBox::Module::Base::writeConfFileNoCheck(APACHE_CONF,
        "captiveportal/captiveportal-apache2.conf.mas",
        [
            http_port => $settings->http_portValue(),
            https_port => $settings->https_portValue(),
        ]);

    # Ldap connection (for auth) config file
    my @params;
    my $ldap = $usersMod->ldap();
    push (@params, ldap_url => $ldap->url());
    push (@params, ldap_bindstring => $ldap->userBindDN('{USERNAME}'));

    my $group = $settings->groupValue();

    if ($group ne '__all__') {
        push (@params, ldap_group => $usersMod->groupDn($group));;
    }

    if ($sldap->enabledValue()) {
        push (@params, ldap2_url => $sldap->urlValue());
        push (@params, ldap2_bindstring => $sldap->binddnValue());
    }

    EBox::Module::Base::writeConfFileNoCheck(LDAP_CONF,
        "captiveportal/ldap.conf.mas",
        \@params);

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

sub _daemons
{
    my ($self) = @_;

    return [
        {
            'name' => 'zentyal.apache2-captiveportal'
        },
        {
            'name' => 'zentyal.captived'
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

# LdapModule implmentation
sub _ldapModImplementation
{
    my ($self) = @_;
    return $self->{cpldap};
}

# Function: usesPort
#
#   Implements EBox::FirewallObserver interface
#
sub usesPort # (protocol, port, iface)
{
    my ($self, $protocol, $port, $iface) = @_;

    ($protocol eq 'tcp') or return undef;
    ($self->isEnabled()) or return undef;

    my $model = $self->model('Settings');

    ($port eq $model->http_portValue()) and return 1;
    ($port eq $model->https_portValue()) and return 1;

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

    foreach my $chain ('icaptive', 'fcaptive') {
        my $rules = EBox::Sudo::root("iptables -vL $chain -n");
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

    my $user = EBox::Global->modInstance('users')->userByUID($username);
    my $quota = $self->{cpldap}->getQuota($user);

    # No limit
    return 0 if ($quota == 0);

    $quota += $extension;

    # check quota
    return $bwusage > $quota;
}

# Function: removeSession
#
#   Removes the session file for the given session id
#
sub removeSession
{
    my ($self, $sid) = @_;

    unless (unlink(SIDS_DIR . $sid)) {
        throw EBox::Exceptions::External(_("Couldn't remove session file"));
    }
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

1;
