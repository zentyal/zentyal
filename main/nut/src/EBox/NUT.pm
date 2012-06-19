# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::NUT;

use strict;
use warnings;

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
                                        'separator' => 'Core',
                                        'order' => 70);

    my $item = new EBox::Menu::Item('url' => 'NUT/Composite/General',
                                    'text' => $self->printableName(),
                                    'order' => 55);
    $folder->add($item);
    $root->add($folder);
}

# Method: initialSetup
#
# Overrides:
#
#   <EBox::Module::Base::initialSetup>
#
sub initialSetup
{
    my ($self, $version) = @_;

    unless ($version) {
        # TODO Setup firewall rules when server/client modes will be supported
        #my $services = EBox::Global->modInstance('services');
        #my $serviceName = 'FTP';
        #unless($services->serviceExists(name => $serviceName)) {
        #    $services->addMultipleService(
        #        'name' => $serviceName,
        #        'description' => __('Zentyal FTP Server'),
        #        'internal' => 1,
        #        'readOnly' => 1,
        #        'services' => $self->_services(),
        #    );
        #}
        #my $firewall = EBox::Global->modInstance('firewall');
        #$firewall->setInternalService($serviceName, 'accept');
        #$firewall->saveConfigRecursive();
    }
}

# Method: actions
#
# Overrides:
#
#   <Override EBox::Module::Service::actions>
#
sub actions
{
    return [
        #{
        #    'action' => __('Generate SSL certificates'),
        #    'reason' => __('Zentyal will self-signed SSL certificates for FTP service.'),
        #    'module' => 'ftp'
        #},
    ];
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
        #my @usedFiles;
        #push (@usedFiles, { 'file' => '/etc/vsftpd.conf',
        #                    'module' => 'ftp',
        #                    'reason' => __('To configure vsftpd.')
        #                  });
        #push (@usedFiles, { 'file' => '/etc/pam.d/vsftpd',
        #                    'module' => 'ftp',
        #                    'reason' => __('To configure vsftpd with LDAP authentication.')
        #                  });
        #return \@usedFiles;
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
    use Data::Dumper;
    EBox::debug(Dumper($upsList));
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
            'name' => 'nut',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/nut/upsd.pid', '/var/run/nut/upsmon.pid'],
        },
    ];
}

1;
