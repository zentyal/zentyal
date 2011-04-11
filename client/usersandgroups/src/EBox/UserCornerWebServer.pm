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
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package EBox::UserCornerWebServer;

use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::Menu::Root;

use strict;
use warnings;

use base qw(EBox::Module::Service
            EBox::Model::ModelProvider
            );

use constant USERCORNER_APACHE => EBox::Config->conf() . '/user-apache2.conf';
use constant USERCORNER_REDIS => '/var/lib/ebox-usercorner/conf/redis.conf';
use constant USERCORNER_REDIS_PASS => '/var/lib/ebox-usercorner/conf/redis.passwd';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'usercorner',
            domain => 'ebox-usersandgroups',
            printableName => __n('User Corner'),
            @_);

    bless($self, $class);
    return $self;
}


# Method: enableModDepends
#
#   Override EBox::Module::Service::enableModDepends
#
sub enableModDepends
{
    return ['users'];
}


# Method: actions
#
#       Override EBox::Module::Service::actions
#
sub actions
{
    return [
            {
             'action' => __('Migrate configured modules'),
             'reason' => __('Required for usercorner access to configured modules'),
             'module' => 'usercorner'
        }
    ];
}

# Method: enableActions
#
#       Override EBox::Module::Service::enableActions
#
sub enableActions
{
    my ($self) = @_;

    if ($self->_isSlave()) {
        throw EBox::Exceptions::External(
            __('User corner is only available in master or standalone servers')
                                        );
    }

    (-d (EBox::Config::conf() . 'configured')) and return;

    my $names = EBox::Global->modNames();
    mkdir(EBox::Config::conf() . 'configured.tmp/');
    foreach my $name (@{$names}) {
        my $mod = EBox::Global->modInstance($name);
        my $class = 'EBox::Module::Service';
        if ($mod->isa($class) and $mod->configured()) {
            EBox::Sudo::command('touch ' . EBox::Config::conf() . "configured.tmp/" . $mod->name());
        }
    }
    rename(EBox::Config::conf() . "configured.tmp", EBox::Config::conf() . "configured");
}

sub _isSlave
{
    my ($self) = @_;
    my $usersMod = EBox::Global->modInstance('users');
    return ($usersMod->mode() eq 'slave') or ($usersMod->adsyncEnabled());
}

# Method: modelClasses
#
# Overrides:
#
#       <EBox::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [ 'EBox::UserCornerWebServer::Model::Settings' ];
}

# Method: _daemons
#
#  Override <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        {
            'name' => 'ebox.apache2-usercorner'
        },
        {
            'name' => 'ebox.redis-usercorner'
        }
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

    # Overwrite the listening port conf file
    EBox::Module::Base::writeConfFileNoCheck(USERCORNER_APACHE,
        "usersandgroups/user-apache2.conf.mas",
        [ port => $settings->portValue() ],
    );

    # Write user corner redis file
    $self->{redis}->writeConfigFile('ebox-usercorner');
}

# Method: menu
#
#        Show the usercorner menu entry
#
# Overrides:
#
#        <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;
    my $item = new EBox::Menu::Item(name => 'UserCorner',
                                    text => $self->printableName(),
                                    separator => 'Office',
                                    url => 'UserCorner/View/Settings',
                                    order => 530
    );
    $root->add($item);
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

sub certificates
{
    my ($self) = @_;

    return [
            {
             service =>  __(q{User Corner web server}),
             path    =>  '/var/lib/ebox-usercorner/ssl/ssl.pem',
             user => 'ebox-usercorner',
             group => 'ebox-usercorner',
             mode => '0400',
            },

           ];
}


1;
