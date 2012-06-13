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
        # FIXME Does UPS need firewall rules?
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

    #$self->writeConfFile('/etc/pam.d/vsftpd',
    #                     '/ftp/vsftpd.mas',
    #                     [ enabled => $userHomes ]);
}

sub _daemons
{
    return [
        #{
        #    'name' => 'vsftpd',
        #},
    ];
}

1;
