# Copyright (C) 2010-2013 Zentyal S.L.
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

# Class: EBox::FTP
use strict;
use warnings;

package EBox::FTP;

use base qw(EBox::Module::Service EBox::FirewallObserver);

use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'ftp',
                                      printableName => 'FTP',
                                      @_);
    bless ($self, $class);
    return $self;
}

# Method: menu
#
#       Add an entry to the menu with this module.
#
# Overrides:
#
#       <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;
    $root->add(new EBox::Menu::Item('url' => 'FTP/View/Options',
                                    'icon' => 'ftp',
                                    'text'  => $self->printableName(),
                                    'order' => 565));
}

# Method: initialSetup
#
# Overrides:
#
#       <EBox::Module::Base::initialSetup>
#
sub initialSetup
{
    my ($self, $version) = @_;

    # Create default rules and services
    # only if installing the first time
    unless ($version) {
        my $network = EBox::Global->modInstance('network');

        my $serviceName = 'FTP';
        unless($network->serviceExists(name => $serviceName)) {
            $network->addMultipleService(
                'name' => $serviceName,
                'description' => __('Zentyal FTP Server'),
                'internal' => 1,
                'readOnly' => 1,
                'services' => $self->_services(),
            );
        }

        my $firewall = EBox::Global->modInstance('firewall');
        $firewall->setInternalService($serviceName, 'accept');

        $firewall->saveConfigRecursive();
    }
}

sub _services
{
    return [
             {
                 'protocol' => 'tcp',
                 'sourcePort' => 'any',
                 'destinationPort' => 20,
             },
             {
                 'protocol' => 'tcp',
                 'sourcePort' => 'any',
                 'destinationPort' => 21,
             },
    ];
}

# Method: actions
#
#   Override EBox::Module::Service::actions
#
sub actions
{
    return [
        {
            'action' => __('Generate SSL certificates'),
            'reason' => __('Zentyal will self-signed SSL certificates for FTP service.'),
            'module' => 'ftp'
        },
    ];
}

# Method: usedFiles
#
# Overrides:
#
#       <EBox::ServiceModule::ServiceInterface::usedFiles>
#
sub usedFiles
{
    my @usedFiles;

    push (@usedFiles, { 'file' => '/etc/vsftpd.conf',
                        'module' => 'ftp',
                        'reason' => __('To configure vsftpd.')
                      });
    push (@usedFiles, { 'file' => '/etc/pam.d/vsftpd',
                        'module' => 'ftp',
                        'reason' => __('To configure vsftpd with LDAP authentication.')
                      });

    return \@usedFiles;
}

# Function: usesPort
#
#       Implements EBox::FirewallObserver interface.
#
sub usesPort # (protocol, port, iface)
{
    my ($self, $protocol, $port, $iface) = @_;

    ($protocol eq 'tcp') or return undef;

    ($self->isEnabled()) or return undef;

    return (($port eq 20) or ($port eq 21));
}

# Method: certificates
#
#   This method is used to tell the CA module which certificates
#   and its properties we want to issue for this service module.
#
# Returns:
#
#   An array ref of hashes containing the following:
#
#       service - name of the service using the certificate
#       path    - full path to store this certificate
#       user    - user owner for this certificate file
#       group   - group owner for this certificate file
#       mode    - permission mode for this certificate file
#
sub certificates
{
    my ($self) = @_;

    return [
            {
             serviceId => 'FTP',
             service =>  __('FTP'),
             path    =>  '/etc/vsftpd/ssl/ssl.pem',
             user => 'ftp',
             group => 'ftp',
             mode => '0440',
            },
           ];
}

# Private functions

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

    my $options = $self->model('Options');
    my $anonymous = $options->anonymous();
    my $userHomes = $options->userHomes();

    my $chrootUsers = $options->chrootUsers();

    my $ssl = $options->ssl();

    $self->writeConfFile('/etc/pam.d/vsftpd',
                         '/ftp/vsftpd.mas',
                         [ enabled => $userHomes ]);

    $self->writeConfFile('/etc/vsftpd.conf',
                         '/ftp/vsftpd.conf.mas',
                         [ anonymous => $anonymous,
                           userHomes => $userHomes,
                           chrootUsers => $chrootUsers,
                           ssl => $ssl ]);
}

sub _daemons
{
    return [ { 'name' => 'vsftpd' } ];
}

sub ftpHome
{
    return '/srv/ftp';
}

1;
