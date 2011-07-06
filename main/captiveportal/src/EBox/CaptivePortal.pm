# Copyright (C) 2011 eBox Technologies S.L.
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
            EBox::FirewallObserver);

use EBox;
use EBox::Gettext;
use EBox::Menu::Item;
use Error qw(:try);
use EBox::Sudo;
use EBox::Ldap;
use EBox::CaptivePortalFirewall;
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
    bless($self, $class);
    return $self;
}

# Method: actions
#
#   Override EBox::Module::Service::actions
#
#sub actions
#{
#    return [
#        {
#            'action' => __('FIXME'),
#            'reason' => __('Zentyal will take care of FIXME'),
#            'module' => 'cactiveportal'
#        }
#    ];
#}

# Method: usedFiles
#
#   Override EBox::Module::Service::usedFiles
#
#sub usedFiles
#{
#    return [
#            {
#             'file' => '/tmp/FIXME',
#             'module' => 'captiveportal',
#             'reason' => __('FIXME configuration file')
#            }
#           ];
#}


sub modelClasses
{
    return [
        'EBox::CaptivePortal::Model::Interfaces',
        'EBox::CaptivePortal::Model::Settings',
        'EBox::CaptivePortal::Model::Users',
    ];
}

sub compositeClasses
{
    return [ 'EBox::CaptivePortal::Composite::General' ];
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

sub _setConf
{
    my ($self) = @_;
    my $settings = $self->model('Settings');
    my $users = EBox::Global->modInstance('users');

    # Apache conf file
    EBox::Module::Base::writeConfFileNoCheck(APACHE_CONF,
        "captiveportal/captiveportal-apache2.conf.mas",
        [
            http_port => $settings->http_portValue(),
            https_port => $settings->https_portValue(),
        ]);

    # Ldap connection (for auth) config file
    EBox::Module::Base::writeConfFileNoCheck(LDAP_CONF,
        "captiveportal/ldap.conf.mas",
        [
            ldap_url => EBox::Ldap::LDAPI,
            bindstring => 'uid={USERNAME},ou=Users,' . $users->ldap->dn,
        ]);

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
            'name' => 'zentyal.captivedaemon'
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
#          mac   => 'XX:XX:XX:XX:XX:XX', (optional, if known)
#          sid  => 'session id',
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
        push(@users, {
            user => $row->valueByName('user'),
            ip => $row->valueByName('ip'),
            mac => $row->valueByName('mac'),
            sid => $row->valueByName('sid'),
            time => $row->valueByName('time'),
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


1;
