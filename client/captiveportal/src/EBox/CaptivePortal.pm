# Copyright (C) 2009-2010 eBox Technologies S.L.
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Class: EBox::CaptivePortal

package EBox::CaptivePortal;

use strict;
use warnings;

use base qw(EBox::Module::Service
            EBox::FirewallObserver
            EBox::Model::ModelProvider
            EBox::Model::CompositeProvider
            EBox::UserCorner::Provider
            );

use EBox::Validate qw( :all );
use EBox::Global;
use EBox::Gettext;
use EBox::UserCorner;
use EBox::Sudo;
use EBox::Dashboard::Section;
use EBox::Dashboard::List;


use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;
use EBox::CaptivePortalFirewall;

use YAML::Tiny;
use File::Basename;

use constant CAPTIVEPORTAL_APACHE => EBox::Config->conf() . '/captiveportal-apache2.conf';
use constant CAPTIVEPORTAL_DIRECTORY => EBox::UserCorner::usercornerdir() . 'captiveportal/';
use constant REFRESH_INTERVAL => 60;

# Method: _create
#
# Overrides:
#
#       <Ebox::Module::_create>
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'captiveportal',
            printableName => __n('Captive Portal'),
            domain => 'ebox-captiveportal',
            @_);
    bless($self, $class);
    return $self;
}

## api functions

# Overrides:
#
#       <EBox::Model::ModelProvider::modelClasses>
sub modelClasses
{
    return [
        'EBox::CaptivePortal::Model::Settings',
        'EBox::CaptivePortal::Model::Interfaces',
    ];
}

# Method: _daemons
#
#  Override <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        {
            'name' => 'ebox.apache2-captiveportal'
        },
        {
            'name' => 'ebox.captiveportald',
        },
    ];
}

# Method: _setConf
#
#  Override <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    # We can assume the listening port is ready available
    my $settings = $self->model('Settings');

    my $usercorner = EBox::Global->modInstance('usercorner');

    # Overwrite the listening port conf file
    EBox::Module::Base::writeConfFileNoCheck(CAPTIVEPORTAL_APACHE,
        "captiveportal/captiveportal-apache2.conf.mas",
        [
            port => $settings->portValue(),
            usercornerport => $usercorner->port()
        ],
    )
}

# Overrides:
#
#       <EBox::Model::ModelProvider::compositeClasses>
sub compositeClasses
{
    return [
        'EBox::CaptivePortal::Composite::General',
    ];
}

# Method: actions
#
#   Override EBox::Module::Service::actions
#
sub actions
{
    return [];
}


# Method: usedFiles
#
#   Override EBox::ServiceModule::ServiceInterface::usedFiles
#
sub usedFiles
{
    return [];
}

# Method: enableActions
#
#   Override EBox::ServiceModule::ServiceInterface::enableActions
#
sub enableActions
{
}

# Method: menu
#
#       Overrides EBox::Module method.
#
#
sub menu
{
    my ($self, $root) = @_;
    my $item = new EBox::Menu::Item(
    'url' => 'CaptivePortal/View/Settings',
    'text' => __('Captive Portal'),
    'order' => 3);
    $root->add($item);
}

sub usersWidget
{
    my ($self, $widget) = @_;
    my $section = new EBox::Dashboard::Section('users');
    $widget->add($section);

    my $users = EBox::CaptivePortalHelper::currentUsers();
    my $titles = [__('User'), 'IP'];
    my $rows = {};
    for my $u (@{$users}) {
        my $id = $u->{'user'};
        $rows->{$id} = [$u->{'user'}, $u->{'ip'}];
    }
    my $ids = [sort keys %{$rows}];
    $section->add(new EBox::Dashboard::List(undef, $titles, $ids, $rows));
}

# Method: widgets
#
# Overrides:
#
#      <EBox::Module::widgets>
#
sub widgets
{
    return {
        'users' => {
            'title' => __('Captive Portal Users'),
            'widget' => \&usersWidget
        },
    }
};

# EBox::UserCorner::Provider implementation
#
# Method: userMenu
#
sub userMenu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('url' => '/CaptivePortal/Index',
        'text' => __('Captive Portal')));
}

sub firewallHelper
{
    my ($self) = @_;
    if ($self->isEnabled()){
        return new EBox::CaptivePortalFirewall();
    }
    return undef;
}

# Method: port
#
#       Returns the port the usercorner webserver is on
#
sub port
{
    my ($self) = @_;
    my $settings = $self->model('Settings');
    return $settings->portValue();
}

# Method: ifaces
#
#       Returns a list of the captive interfaces
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

# Method: interval
#
#   Returns the interval in seconds between two pop-up refreshes
#
sub interval
{
    return REFRESH_INTERVAL;
}

# Method: refresh
#
#   Updates the user information with the IP and the current timestamp
#
sub refresh
{
    my $r = Apache2::RequestUtil->request();

    my $user = $r->user();
    my $ip = $r->connection->remote_ip();

    my $file = CAPTIVEPORTAL_DIRECTORY . $user;

    my $yaml = YAML::Tiny->new();
    $yaml->[0]->{'user'} = $user;
    $yaml->[0]->{'ip'} = $ip;
    $yaml->[0]->{'time'} = time();
    $yaml->write($file);
}

# Method: userIP
#
#    Returns the IP a user logged in from or undef if it's not logged in
#
sub userIP
{
    my ($user) = @_;

    my $file = CAPTIVEPORTAL_DIRECTORY . $user;
    if (! -f $file) {
        return undef;
    }
    my $yaml = YAML::Tiny->read($file);
    return $yaml->[0]->{'ip'};
}

sub addRule
{
    my ($ip) = @_;
    EBox::info("Adding rule for ip $ip");
    EBox::Sudo::root("/sbin/iptables -I icaptive -s $ip -j RETURN");
    EBox::Sudo::root("/sbin/iptables -I fcaptive -s $ip -j RETURN");
}

sub removeRule
{
    my ($ip) = @_;
    EBox::info("Removing rule for ip $ip");
    EBox::Sudo::root("/sbin/iptables -D icaptive -s $ip -j RETURN");
    EBox::Sudo::root("/sbin/iptables -D fcaptive -s $ip -j RETURN");
}

sub _isStale
{
    my ($user) = @_;

    my $file = CAPTIVEPORTAL_DIRECTORY . $user;
    my $yaml = YAML::Tiny->read($file);
    my $time = $yaml->[0]->{'time'};
    if (($time + (2*interval())) < time()) {
        return 1;
    } else {
        return undef;
    }
}

sub removeStaleUsers
{
    for my $file (glob(EBox::CaptivePortal::CAPTIVEPORTAL_DIRECTORY . '*')) {
        my $user = basename($file);
        if (_isStale($user)) {
            my $ip = userIP($user);
            EBox::Sudo::root("rm -f $file");
            removeRule($ip);
        }
    }
}

1;
