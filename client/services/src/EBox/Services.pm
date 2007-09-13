# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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
# 	This class is used to abstract services composed of
# 	protocols and ports.
#
# 	

package EBox::Services;

use strict;
use warnings;

use base qw(EBox::GConfModule EBox::Model::ModelProvider);


use EBox::Validate qw( :all );
use EBox::Global;
use EBox::Services::Model::ServiceConfigurationTable;
use EBox::Services::Model::ServiceTable;
use EBox::Gettext;

use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'services',
            title => __n('Services'),
            domain => 'ebox-objects',
            @_);
    $self->{'serviceModel'} = 
        new EBox::Services::Model::ServiceTable(
                'gconfmodule' => $self,
                'directory' => 'serviceTable');
    $self->{'serviceConfigurationModel'} = 
        new EBox::Services::Model::ServiceConfigurationTable(
                'gconfmodule' => $self,
                'directory' => 'serviceConfigurationTable');
    bless($self, $class);
    return $self;
}

## api functions

# Method: models
#
#      Overrides <EBox::ModelImplementator::models>
#
sub models {
    my ($self) = @_;

    return [$self->{'serviceConfigurationModel'}, $self->{'serviceModel'}];
}

# Method: serviceNames
#
# 	Fetch all the service identifiers and names
#
# Returns:
#
# 	Array ref of  hash refs which contain:
#
# 	'id' - service identifier
# 	'name' service name
#
#	Example:
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

    my @services;
    foreach my $service (@{$self->{'serviceModel'}->printableValueRows()}) {
        push (@services, {'id' => $service->{'id'}, 
                'name' => $service->{'name'}});
    }

    return \@services;
}

# Method: serviceConfiguration
#
#	For a given service identifier it returns its service configuration,
#	that is, the set of protocols and ports.
#
# Returns:
#
# 	Array ref of  hash refs which contain:
#	
#	protocol - it can take one of these: any, tcp, udp, tcp/udp, grep, icmp
#	source	 - it can take: 
#   			"any"
#	    		An integer from 1 to 65536 -> 22
#		    	Two integers separated by colons -> 22:25 
#	destination - same as source
#
#	Example:
#
#	     'protocol' => 'tcp',
#	     'source' => 'any',
#       'destination' => '21:22',
sub serviceConfiguration
{
    my ($self, $id) = @_;

    throw EBox::Exceptions::ArgumentMissing("id") unless defined($id);

    my $row = $self->{'serviceModel'}->find('id' => $id);

    unless (defined($row)) {
        throw EBox::Exceptions::DataNotFound('data' => 'id',
                'value' => $id);
    }

    my $model = $self->{'serviceConfigurationModel'};
    $model->setDirectory($row->{'configuration'}->{'directory'});

    my @conf = map {$_->{'plainValueHash'}} @{$model->rows()};

    return \@conf;
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
#	protocol    - it can take one of these: any, tcp, udp, tcp/udp, grep, icmp
#	sourcePort  - it can take: 
#                   "any"
#                    An integer from 1 to 65536 -> 22
#                   Two integers separated by colons -> 22:25 
#	destinationPort - same as source
#   internal - boolean, internal services can't be modified from the UI
#   readOnly - boolean, set the row unremovable from the UI
#
#	Example:
#
#       'name' => 'ssh',
#       'description' => 'secure shell'.
#	    'protocol' => 'tcp',
#	    'sourcePort' => 'any',
#       'destinationPort' => '21:22',
sub addService 
{
    my ($self, %params) = @_;

    $self->{'serviceModel'}->addService(%params);
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
#	protocol    - it can take one of these: any, tcp, udp, tcp/udp, grep, icmp
#	sourcePort  - it can take: 
#                   "any"
#                    An integer from 1 to 65536 -> 22
#                   Two integers separated by colons -> 22:25 
#	destinationPort - same as source
#   internal - boolean, internal services can't be modified from the UI
#   readOnly - boolean, set the row unremovable from the UI
#
#	Example:
#
#       'name' => 'ssh',
#       'description' => 'secure shell'.
#	    'protocol' => 'tcp',
#	    'sourcePort' => 'any',
#       'destinationPort' => '21:22',
sub setService 
{
    my ($self, %params) = @_;

    $self->{'serviceModel'}->setService(%params);
}

# Method: setAdministrationPort
#
#	Set administration port on service
#
# Parameters:
#
#	port - port
#	
sub setAdministrationPort
{
    my ($self, $port) = @_;

    checkPort($port, __("port"));

	$self->setService('name' => __d('eBox administration'),
                'description' => __d('eBox Administration port'),
                'domain' => __d('ebox-services'),
                'protocol' => 'tcp',
                'sourcePort' => 'any',
                'destinationPort' => $port,
                'internal' => 1,
                'readOnly' => 1);

}

# Method: availablePort 
#
#	Check if a given port for a given protocol is available. That is,
#	no internal service uses it.
#
# Parameters:
#
#   (POSITIONAL)
#   protocol   - it can take one of these: tcp, udp
#   port 	   - An integer from 1 to 65536 -> 22
#
# Returns:
#   boolean - true if it's available, otherwise false
#
sub availablePort
{
    my ($self, %params) = @_;

    return $self->{'serviceModel'}->availablePort(%params);
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
        throw Exceptions::MissingArgument('service');
    }
    
    my $model =  $self->{'serviceModel'};
    my $id = $params{'id'};

    if (not defined($id)) {
        my $name = $params{'name'};
        my $row = $model->findValue('name' => $name);
        unless (defined($row)) {
            throw EBox::Exceptions::External("service $name not found");
        }
        $id = $row->{'id'};
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
        throw Exceptions::MissingArgument('service');
    }
    
    my $model =  $self->{'serviceModel'};
    my $id = $params{'id'};

    my $row;
    if (not defined($id)) {
        my $name = $params{'name'};
        $row = $model->findValue('name' => $name);
    } else {
        $row = $model->findValue('id' => $id);
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
        throw Exceptions::MissingArgument('name');
    }
    
    my $model =  $self->{'serviceModel'};
    my $row = $model->findValue('name' => $name);
    
    return $row->{'id'};
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
    'url' => 'Services/View/ServiceTable',
    'text' => __($self->title),
    'order' => 3);
    $root->add($item);
}

1;
