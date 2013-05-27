# Copyright (C) 2008-2012 eBox Technologies S.L.
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

# Class: EBox::Services
#
#       This class is used to abstract services composed of
#       protocols and ports.
#

package EBox::Services;

use strict;
use warnings;

use base qw(EBox::Module::Config);

use EBox::Validate qw( :all );
use EBox::Services::Model::ServiceConfigurationTable;
use EBox::Services::Model::ServiceTable;
use EBox::Gettext;

use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;

use Error qw(:try);

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'services',
                                      printableName => __('Services'),
                                      @_);
    bless($self, $class);
    return $self;
}

# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    foreach my $service (@{$self->_defaultServices()}) {
        $service->{'sourcePort'} = 'any';
        $service->{'readOnly'} = 1;
        if ($self->serviceExists('name' => $service->{'name'})) {
            $self->setService(%{$service});
        } else {
            $self->addService(%{$service});
        }
    }
}

sub _defaultServices
{
    my ($self) = @_;

    my $apachePort;
    try {
        $apachePort = $self->global()->modInstance('apache')->port();
    } otherwise {
        $apachePort = 443;
    };

    return [
        {
         'name' => 'any',
         'printableName' => __('Any'),
         'description' => __('Any protocol and port'),
         'protocol' => 'any',
         'destinationPort' => 'any',
         'internal' => 0,
        },
        {
         'name' => 'any UDP',
         'printableName' => __('Any UDP'),
         'description' => __('Any UDP port'),
         'protocol' => 'udp',
         'destinationPort' => 'any',
         'internal' => 0,
        },
        {
         'name' => 'any TCP',
         'printableName' => __('Any TCP'),
         'description' => __('Any TCP port'),
         'protocol' => 'tcp',
         'destinationPort' => 'any',
         'internal' => 0,
        },
        {
         'name' => 'administration',
         'printableName' => __('Zentyal Administration'),
         'description' => __('Zentyal Administration Web Server'),
         'protocol' => 'tcp',
         'destinationPort' => $apachePort,
         'internal' => 1,
        },
        {
         'name' => 'ssh',
         'printableName' => 'SSH',
         'description' => __('Secure Shell'),
         'protocol' => 'tcp',
         'destinationPort' => '22',
         'internal' => 0,
        },
        {
         'name' => 'HTTP',
         'printableName' => 'HTTP',
         'description' => __('HyperText Transport Protocol'),
         'protocol' => 'tcp',
         'destinationPort' => '80',
         'internal' => 0,
        },
        {
         'name' => 'HTTPS',
         'printableName' => 'HTTPS',
         'description' => __('HyperText Transport Protocol over SSL'),
         'protocol' => 'tcp',
         'destinationPort' => '443',
         'internal' => 0,
        },
    ];
}

# Method: serviceNames
#
#       Fetch all the service identifiers and names
#
# Returns:
#
#       Array ref of  hash refs which contain:
#
#       'id' - service identifier
#       'name' service name
#
#       Example:
#         [
#          {
#            'name' => 'ssh',
#            'id' => 'serv7999'
#          },
#          {
#            'name' => 'ftp',
#            'id' => 'serv7867'
#          }
#        ];
sub serviceNames
{
    my ($self) = @_;

    my $servicesModel = $self->model('ServiceTable');
    my @services;

    foreach my $id (@{$servicesModel->ids()}) {
        my $name = $servicesModel->row($id)->valueByName('name');
        push @services, {
            'id' => $id,
            'name' => $name
           };
    }

    return \@services;
}

# Method: serviceConfiguration
#
#       For a given service identifier it returns its service configuration,
#       that is, the set of protocols and ports.
#
# Returns:
#
#       Array ref of  hash refs which contain:
#
#       protocol - it can take one of these: any, tcp, udp, tcp/udp, grep, icmp
#       source   - it can take:
#                       "any"
#                       An integer from 1 to 65536 -> 22
#                       Two integers separated by colons -> 22:25
#       destination - same as source
#
#       Example:
#         [
#             {
#              'protocol' => 'tcp',
#               'source' => 'any',
#               'destination' => '21:22',
#             }
#         ]
sub serviceConfiguration
{
    my ($self, $id) = @_;

    throw EBox::Exceptions::ArgumentMissing("id") unless defined($id);

    my $row = $self->model('ServiceTable')->row($id);

    unless (defined($row)) {
        throw EBox::Exceptions::DataNotFound('data' => 'service by id',
                'value' => $id);
    }

    my $model = $row->subModel('configuration');

    my @conf;
    foreach my $id (@{$model->ids()}) {
        my $subRow = $model->row($id);
        push (@conf, {
                        'protocol' => $subRow->valueByName('protocol'),
                        'source' => $subRow->valueByName('source'),
                        'destination' => $subRow->valueByName('destination')
                      });
    }

    return \@conf;
}

# Method: serviceIptablesArgs
#
#  get a list with the iptables arguments required to match each of the
#  configurations of the service (see serviceConfiguration)
#
#  Warning:
#    for any/any/any configuration a empty string is the correct iptables argument
sub serviceIptablesArgs
{
    my ($self, $id) = @_;
    my @args;
    my @conf =  @{ $self->serviceConfiguration($id) };
    foreach my $conf (@conf) {
        my $args = '';
        if ($conf->{protocol} ne 'any') {
            $args .= '--protocol ' . $conf->{protocol};
        }
        if ($conf->{source} ne 'any') {
            $args .= ' --sport ' . $conf->{source};
        }
        if ($conf->{destination} ne 'any') {
            $args .= ' --dport ' . $conf->{destination};
        }

        push @args, $args;
    }

    return \@args;
}

# Method: addService
#
#   Add a service to the services table
#
# Parameters:
#
#   (NAMED)
#
#   name        - service's name
#   description - service's description
#   protocol    - it can take one of these: any, tcp, udp, tcp/udp, grep, icmp
#   sourcePort  - it can take:
#                   "any"
#                   An integer from 1 to 65536 -> 22
#                   Two integers separated by colons -> 22:25
#   destinationPort - same as source
#   internal - boolean, internal services can't be modified from the UI
#   readOnly - boolean, set the row unremovable from the UI
#
#       Example:
#
#       'name' => 'ssh',
#       'description' => 'secure shell'.
#           'protocol' => 'tcp',
#           'sourcePort' => 'any',
#       'destinationPort' => '21:22',
#
#   Returns:
#
#   string - id of the new created row
sub addService
{
    my ($self, %params) = @_;

    return $self->model('ServiceTable')->addService(%params);
}

# Method: addMultipleService
#
#   Add a multi protocol service to the services table
#
# Parameters:
#
#   (NAMED)
#
#   name        - service's name
#   description - service's description
#   internal - boolean, internal services can't be modified from the UI
#   readOnly - boolean, set the row unremovable from the UI
#
#   services - array ref of hash ref containing:
#
#           protocol    - it can take one of these: any, tcp, udp,
#                                                   tcp/udp, grep, icmp
#           sourcePort  - it can take:  "any"
#                                   An integer from 1 to 65536 -> 22
#                                   Two integers separated by colons -> 22:25
#           destinationPort - same as source
#
#
#       Example:
#
#       'name' => 'ssh',
#       'description' => 'secure shell'.
#       'services' => [
#                       {
#                               'protocol' => 'tcp',
#                               'sourcePort' => 'any',
#                           'destinationPort' => '21:22'
#                        },
#                        {
#                               'protocol' => 'tcp',
#                               'sourcePort' => 'any',
#                           'destinationPort' => '21:22'
#                        }
#                     ];
#
#   Returns:
#
#   string - id of the new created row
sub addMultipleService
{
    my ($self, %params) = @_;

    return $self->model('ServiceTable')->addMultipleService(%params);
}

# Method: setService
#
#   Set a existing service to the services table
#
# Parameters:
#
#   (NAMED)
#
#   name        - service's name
#   description - service's description
#       protocol    - it can take one of these: any, tcp, udp, tcp/udp, grep, icmp
#       sourcePort  - it can take:
#                   "any"
#                    An integer from 1 to 65536 -> 22
#                   Two integers separated by colons -> 22:25
#       destinationPort - same as source
#   internal - boolean, internal services can't be modified from the UI
#   readOnly - boolean, set the row unremovable from the UI
#
#       Example:
#
#       'name' => 'ssh',
#       'description' => 'secure shell'.
#           'protocol' => 'tcp',
#           'sourcePort' => 'any',
#       'destinationPort' => '21:22',
sub setService
{
    my ($self, %params) = @_;

    $self->model('ServiceTable')->setService(%params);
}

# Method: setMultipleService
#
#   Set a multi protocol service to the services table
#
# Parameters:
#
#   (NAMED)
#
#   name        - service's name
#   description - service's description
#   internal - boolean, internal services can't be modified from the UI
#   readOnly - boolean, set the row unremovable from the UI
#
#   services - array ref of hash ref containing:
#
#	    protocol    - it can take one of these: any, tcp, udp,
#	                                            tcp/udp, grep, icmp
#	    sourcePort  - it can take:  "any"
#                                   An integer from 1 to 65536 -> 22
#                                   Two integers separated by colons -> 22:25
#	    destinationPort - same as source
#
#
#	Example:
#
#       'name' => 'ssh',
#       'description' => 'secure shell'.
#       'services' => [
#                       {
#	                        'protocol' => 'tcp',
#	                        'sourcePort' => 'any',
#                               'destinationPort' => '21:22'
#                        },
#                        {
#	                        'protocol' => 'tcp',
#	                        'sourcePort' => 'any',
#                               'destinationPort' => '21:22'
#                        }
#                     ];
#
#   Returns:
#
#   string - id of the updated row
#
sub setMultipleService
{
    my ($self, %params) = @_;

    $self->model('ServiceTable')->setMultipleService(%params);
}

# Method: setAdministrationPort
#
#       Set administration port on service
#
# Parameters:
#
#       port - port
#
sub setAdministrationPort
{
    my ($self, $port) = @_;

    checkPort($port, __("port"));

    $self->setService(
            'name' => 'administration',
            'printableName' => __('Zentyal Administration'),
            'description' => __('Zentyal Administration Web Server'),
            'protocol' => 'tcp',
            'sourcePort' => 'any',
            'destinationPort' => $port,
            'internal' => 1,
            'readOnly' => 1
    );
}

# Method: availablePort
#
#       Check if a given port for a given protocol is available. That is,
#       no internal service uses it.
#
# Parameters:
#
#   (POSITIONAL)
#   protocol   - it can take one of these: tcp, udp
#   port           - An integer from 1 to 65536 -> 22
#
# Returns:
#   boolean - true if it's available, otherwise false
#
sub availablePort
{
    my ($self, %params) = @_;

    return $self->model('ServiceTable')->availablePort(%params);
}

# Method: serviceFromPort
#
#       Get the service name that it's using a port.
#
# Parameters:
#
#   (POSITIONAL)
#   protocol   - it can take one of these: tcp, udp
#   port       - An integer from 1 to 65536 -> 22
#
# Returns:
#   string - the service name, undef otherwise
#
sub serviceFromPort
{
    my ($self, %params) = @_;

    return $self->model('ServiceTable')->serviceFromPort(%params);
}

# Method: removeService
#
#  Remove a service from the  services table
#
# Parameters:
#
#   (NAMED)
#
#   You can select the service using one of the following parameters:
#
#       name - service's name
#       id - service's id
sub removeService
{
    my ($self, %params) = @_;

    unless (exists $params{'id'} or exists $params{'name'}) {
        throw EBox::Exceptions::MissingArgument('service');
    }

    my $model =  $self->model('ServiceTable');
    my $id = $params{'id'};

    if (not defined($id)) {
        my $name = $params{'name'};
        my $row = $model->findValue('name' => $name);
        unless (defined($row)) {
            throw EBox::Exceptions::External("service $name not found");
        }
        $id = $row->id();
    }

    $model->removeRow($id, 1);
}

# Method: serviceExists
#
#   Check if a given service already exits
#
# Paremeters:
#
#   (NAMED)
#   You can select the service using one of the following parameters:
#
#       name - service's name
#       id - service's id
sub serviceExists
{
    my ($self, %params) = @_;

    unless (exists $params{'id'} or exists $params{'name'}) {
        throw EBox::Exceptions::MissingArgument('service id or name');
    }

    my $model =  $self->model('ServiceTable');
    my $id = $params{'id'};

    my $row;
    if (not defined($id)) {
        my $name = $params{'name'};
        $row = $model->findValue('name' => $name);
    } else {
        $row = $model->row($id);
    }

    return defined($row);
}

# Method: serviceId
#
#   Given a service's name it returns its id
#
# Paremeters:
#
#   (POSITIONAL)
#
#   name - service's name
#
# Returns:
#
#   service's id if it exists, otherwise undef
sub serviceId
{
    my ($self, $name) = @_;

    unless (defined($name)) {
        throw EBox::Exceptions::MissingArgument('name');
    }

    my $model = $self->model('ServiceTable');
    my $row = $model->findValue('name' => $name);
    if (not defined $row) {
        return undef;
    }

    return $row->id();
}


# Method: menu
#
#       Overrides EBox::Module method.
#
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder('name' => 'Network',
                                        'text' => __('Network'),
                                        'separator' => 'Core',
                                        'order' => 40);

    my $item = new EBox::Menu::Item('url' => 'Network/Services',
                                    'text' => __($self->title),
                                    'order' => 50);

    $folder->add($item);
    $root->add($folder);
}

1;
