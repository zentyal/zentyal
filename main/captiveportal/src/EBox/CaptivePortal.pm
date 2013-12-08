# Copyright (C) 2011-2011 Zentyal S.L.
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

package EBox::CaptivePortal;

use strict;
use warnings;

use base qw(EBox::Module::Service
            EBox::Model::ModelProvider
            EBox::Model::CompositeProvider
            EBox::FirewallObserver
            EBox::LdapModule);

use EBox;
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
use constant EXPIRATION_TIME => 60;

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

sub modelClasses
{
    return [
        'EBox::CaptivePortal::Model::Interfaces',
        'EBox::CaptivePortal::Model::Settings',
        'EBox::CaptivePortal::Model::BWSettings',
        'EBox::CaptivePortal::Model::Users',
        'EBox::CaptivePortal::Model::CaptiveUser',
        'EBox::CaptivePortal::Model::SecondaryLDAP',
    ];
}

sub compositeClasses
{
    return [
        'EBox::CaptivePortal::Composite::GeneralSettings',
        'EBox::CaptivePortal::Composite::General',
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
    my $users = EBox::Global->modInstance('users');

    # Apache conf file
    EBox::Module::Base::writeConfFileNoCheck(APACHE_CONF,
        "captiveportal/captiveportal-apache2.conf.mas",
        [
            http_port => $settings->http_portValue(),
            https_port => $settings->https_portValue(),
        ]);

    # Ldap connection (for auth) config file
    my @params;
    push (@params, ldap_url => EBox::Ldap::LDAPI);
    push (@params, ldap_bindstring => 'uid={USERNAME},ou=Users,' . $users->ldap->dn);

    my $group = $settings->groupValue();

    if ($group ne '__all__') {
        push (@params, ldap_group => $group);
        push (@params, ldap_groupsdn => $users->groupsDn());
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
    my $ids = $model->ids();
    my @users;
    for my $id (@{$ids}) {
        my $row = $model->row($id);
        my $bwusage = 0;

        if ($self->_bwmonitor()) {
            $bwusage = $row->valueByName('bwusage');
        }

        push(@users, {
            user => $row->valueByName('user'),
            ip => $row->valueByName('ip'),
            mac => $row->valueByName('mac'),
            sid => $row->valueByName('sid'),
            time => $row->valueByName('time'),
            bwusage => $bwusage,
        });
    }
    return \@users;
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
    my ($self, $user) = @_;

    my $ip = $user->{ip};
    my $name = $user->{user};
    my $mac = $user->{mac};
    my $macSrc = '';
    $macSrc = "-m mac --mac-source $mac" if defined($mac);
    return "-s $ip $macSrc -m comment --comment 'user:$name' -j RETURN";
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

    return time() > ($time + EXPIRATION_TIME + 30);
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
    my ($self, $username, $bwusage) = @_;

    my $quota = $self->{cpldap}->getQuota($username);

    # No limit
    return 0 if ($quota == 0);

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


sub _bwmonitor {
    my $bwmonitor = EBox::Global->modInstance('bwmonitor');
    return defined($bwmonitor) and $bwmonitor->isEnabled();
}


1;
