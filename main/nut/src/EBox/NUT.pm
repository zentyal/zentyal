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

package EBox::NUT;

use base qw(EBox::Module::Service);

use EBox::Gettext;

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'nut',
                                      printableName => __('UPS'),
                                      @_);
    bless ($self, $class);
    return $self;
}

# Method: menu
#
#   Add an entry to the menu with this module.
#
# Overrides:
#
#   <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder('name' => 'Maintenance',
                                        'text' => __('Maintenance'),
                                        'icon' => 'maintenance',
                                        'separator' => 'Core',
                                        'order' => 70);

    my $item = new EBox::Menu::Item('url' => 'Maintenance/NUT',
                                    'text' => $self->printableName(),
                                    'order' => 55);
    $folder->add($item);
    $root->add($folder);
}

# Method: usedFiles
#
# Overrides:
#
#   <EBox::ServiceModule::ServiceInterface::usedFiles>
#
sub usedFiles
{
    return [
        { file => '/etc/nut/nut.conf',
          module => 'nut',
          reason => __('To configure the NUT daemon mode.') },
        { file => '/etc/nut/ups.conf',
          module => 'nut',
          reason => __("To configure the UPS's drivers.") },
        { file => '/etc/nut/upsd.conf',
          module => 'nut',
          reason => __('To configure the NUT daemon') },
        { file => '/etc/nut/upsd.users',
          module => 'nut',
          reason => __('To configure the authorized NUT daemon users') },
        { file => '/etc/nut/upsmon.conf',
          module => 'nut',
          reason => __('To configure the NUT client') },
    ];
}

# Method: _setConf
#
#        Regenerate the configuration.
#
# Overrides:
#
#       <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    my $nutMode = $self->model('Mode')->modeValue();
    $self->writeConfFile('/etc/nut/nut.conf',
                         '/nut/nut.conf.mas',
                         [ mode => $nutMode ]);

    my $upsList = $self->model('UPS')->upsList();
    $self->writeConfFile('/etc/nut/ups.conf',
                         '/nut/ups.conf.mas',
                         [ upsList => $upsList ]);

    my $listen = [ '127.0.0.1' ]; # TODO If server, the addresses where listen
    my $port   = 3493;
    $self->writeConfFile('/etc/nut/upsd.conf',
                         '/nut/upsd.conf.mas',
                         [ listen => $listen,
                           port   => $port ]);

    # TODO Modelize upsd users
    my $upsdUsers = [
        {
            name     => 'upsmon',
            password => 'upsmon',
            actions  => ['set'],
            upsmon   => 'master',
        }
    ];
    $self->writeConfFile('/etc/nut/upsd.users',
                         '/nut/upsd.users.mas',
                         [ users => $upsdUsers ]);

    # TODO Modelize upsmon users
    my $monitoredList = [];
    foreach my $entry (@{$upsList}) {
        my $monitored = {
            label    => $entry->{label},
            host     => 'localhost',
            nPSU     => 1,
            user     => 'upsmon',
            password => 'upsmon',
            upsmon   => 'master',
        };
        push (@{$monitoredList}, $monitored);
    }
    $self->writeConfFile('/etc/nut/upsmon.conf',
                         '/nut/upsmon.conf.mas',
                         [ monitoredList => $monitoredList ]);

    # Ensure files security
    my @cmds;
    push (@cmds, 'chown root:nut /etc/nut/ups.conf');
    push (@cmds, 'chmod 640 /etc/nut/ups.conf');
    push (@cmds, 'chown root:nut /etc/nut/upsd.conf');
    push (@cmds, 'chmod 640 /etc/nut/upsd.conf');
    push (@cmds, 'chown root:nut /etc/nut/upsd.users');
    push (@cmds, 'chmod 640 /etc/nut/upsd.users');
    push (@cmds, 'chown root:nut /etc/nut/upsmon.conf');
    push (@cmds, 'chmod 640 /etc/nut/upsmon.conf');
    push (@cmds, 'addgroup nut dialout');
    EBox::Sudo::root(@cmds);
}

sub _daemons
{
    return [
        {
            'name' => 'nut-server',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/nut/upsd.pid', '/var/run/nut/upsmon.pid'],
        },
    ];
}

1;
