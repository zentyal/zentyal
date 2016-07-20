# Copyright (C) 2008-2013 Zentyal S.L.
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

# Class: EBox::Network::Model::ServiceTable
#
#   This class describes the data model used to store services.
#   That is, a set of abstractions for protocols and ports.
#
#   This table stores basically the following fields:
#
#   name - service's name
#   description - service's description (optional)
#   configuration - hasMany relation with model
#                   <EBox::Network::Model::ServiceConfigurationTable>
#
#
#   Let's see an example of the structure returned by printableValueRows()
#
#   [
#     {
#       'name' => 'ssh',
#       'id' => 'serv7999',
#       'description' => 'Secure Shell'
#
#       'configuration' => {
#           'model' => 'ServiceConfigurationTable',
#           'values' => [
#            {
#               'source' => 'any',
#               'protocol' => 'TCP',
#               'destination' => '22',
#               'id' => 'serv16'
#            }
#           ],
#       },
#     },
#     {
#       'id' => 'serv7867',
#       'name' => 'ftp',
#       'description' => 'File transfer protocol'
#       'configuration' => {
#           'model' => 'ServiceConfigurationTable',
#           'values' => [
#           {
#               'source' => 'any',
#               'protocol' => 'TCP',
#               'destination' => '21:22',
#               'id' => 'serv6891'
#           }
#           ],
#       },
#     }
#   ]

use strict;
use warnings;

package EBox::Network::Model::ServiceTable;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Types::HasMany;
use EBox::Sudo;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::External;

use base 'EBox::Model::DataTable';

sub new
{
        my $class = shift;
        my %parms = @_;

        my $self = $class->SUPER::new(@_);
        bless($self, $class);

        return $self;
}

sub _table
{
    my @tableHead =
    (
        new EBox::Types::Boolean(
            'fieldName' => 'internal',
            'printableName' => __('Internal'),
            'editable' => 1,
            'hidden' => 1,
            'help'  => __('Tick this field if there is actually a service ' .
                'on the machine using the ports configured for this service. ' .
                'This helps Zentyal to know what ports are already busy')
        ),
        new EBox::Types::Text(
            'fieldName' => 'name',
            'printableName' => __('Internal name'),
            'localizable' => 1,
            'size' => '20',
            'unique' => 1,
            'editable' => 1,
            'hidden' => 1,
            'optional' => 1,
        ),
        new EBox::Types::Text(
            'fieldName' => 'printableName',
            'printableName' => __('Service name'),
            'localizable' => 1,
            'size' => '20',
            # FIXME: Commented for problems with i18n, maybe it can be restored
            # after fixing utf8 problems?
            #'unique' => 1,
            'editable' => 1
        ),
        new EBox::Types::Text(
            'fieldName' => 'description',
            'printableName' => __('Description'),
            'size' => '30',
            'editable' => 1,
            'optional' => 1,
        ),
        new EBox::Types::HasMany (
            'fieldName' => 'configuration',
            'printableName' => __('Configuration'),
            'foreignModel' => 'ServiceConfigurationTable',
            'view' => '/Network/View/ServiceConfigurationTable',
        )
    );

    my $dataTable =
    {
        'tableName' => 'ServiceTable',
        'automaticRemove' => 1,
        'printableTableName' => __('List of services'),
        'pageTitle' => __('Services'),
        'defaultController' =>
            '/Network/Controller/ServiceTable',
        'defaultActions' =>
            ['add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'menuNamespace' => 'Network/View/ServiceTable',
        'HTTPUrlView'   => 'Network/View/ServiceTable',
        'class' => 'dataTable',
        'help' => _servicesHelp(), # FIXME
        'printableRowName' => __('service'),
        'sortedBy' => 'name',
    };

    return $dataTable;
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
    my ($self, $protocol, $port) = @_;
    return not $self->portUsedByService($protocol, $port);
}

sub portUsedByService
{
    my ($self, $protocol, $port) = @_;

    unless (defined($protocol)) {
        throw EBox::Exceptions::MissingArgument('protocol');
    }

    unless (defined($port)) {
        throw EBox::Exceptions::MissingArgument('port');
    }

    my $internals = $self->findAll('internal' => 1);

    for my $id (@{$internals}) {
        my $service = $self->row($id);
        my $serviceConf = $service->subModel('configuration');
        for my $subId (@{$serviceConf->findAllValue('destination' => $port)}) {
            my $row = $serviceConf->row($subId);
            if ($row->valueByName('protocol') eq $protocol) {
                return $service->valueByName('printableName')
            }
        }
    }

    return undef;
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
    my ($self, $protocol, $port) = @_;

    unless (defined($protocol)) {
        throw EBox::Exceptions::MissingArgument('protocol');
    }

    unless (defined($port)) {
        throw EBox::Exceptions::MissingArgument('port');
    }

    my $internals = $self->findAll('internal' => 1);

    for my $id (@{$internals}) {
        my $service = $self->row($id);
        my $serviceConf = $service->subModel('configuration');
        for my $subId (@{$serviceConf->findAllValue('destination' => $port)}) {
            my $row = $serviceConf->row($subId);
            return $service->valueByName('name') if ($row->valueByName('protocol') eq $protocol);
        }
    }

    return undef;
}

# Method: addService
#
#   Add service to the services table. Note this method must exist
#   because we add services manually from other modules
#
# Parameters:
#
#   (NAMED)
#   name          - service's internal name
#   printableName - service's printable name
#   description   - service's description
#   protocol      - it can take one of these: any, tcp, udp, tcp/udp, grep, icmp
#   sourcePort    - it can take:
#                     "any"
#                     An integer from 1 to 65536 -> 22
#                     Two integers separated by colons -> 22:25
#   destinationPort - same as source
#   internal - booelan, to indicate if the service is internal or not
#   readOnly - the service can't be deleted or modified
#
#   Example:
#
#       'protocol' => 'tcp',
#       'source' => 'any',
#       'destination' => '21:22',
#
sub addService
{
    my ($self, %params) = @_;

    my $id = $self->addRow(_serviceParams(%params));

    unless (defined($id)) {
        throw EBox::Exceptions::Internal("Couldn't add name and description");
    }

    my $serviceConf = $self->parentModule()->model('ServiceConfigurationTable');
    unless (defined($serviceConf)) {
        throw EBox::Exceptions::Internal(
                    "Couldn't get ServiceConfigurationTable");
    }

    $serviceConf->setDirectory($self->{'directory'} . "/$id/configuration");
    $serviceConf->addRow(_serviceConfParams(%params));

    return $id;
}

# Method: setService
#
#   Add service to the services table. Note this method must exist
#   because we set services manually from other modules.
#
#   It only makes sense with services having just one protocol.
#
# Parameters:
#
#   (NAMED)
#   name       - service's name
#   description - service's description
#   protocol   - it can take one of these: any, tcp, udp, tcp/udp, grep, icmp
#   sourcePort - it can take:
#               "any"
#               An integer from 1 to 65536 -> 22
#               Two integers separated by colons -> 22:25
#   destinationPort - same as source
#   internal - booelan, to indicate if the service is internal or not
#   readOnly - the service can't be deleted or modified
#
#   Example:
#
#       'protocol' => 'tcp',
#       'source' => 'any',
#       'destination' => '21:22',
#
sub setService
{
    my ($self, %params) = @_;

    my $name = $params{'name'};
    unless (defined($name)) {
        throw EBox::Exceptions::MissingArgument('name');
    }

    my $row = $self->findValue('name' => $name);
    unless (defined($row)) {
       throw EBox::Exceptions::DataNotFound('data' => 'service',
                                            'value' => 'name');
    }

    my $id = $row->id();
    $self->setRow(1, _serviceParams(%params), 'id' => $id);

    my $serviceConf = $self->parentModule()->model('ServiceConfigurationTable');
    unless (defined($serviceConf)) {
        throw EBox::Exceptions::Internal(
                    "Couldn't get ServiceConfigurationTable");
    }

    $serviceConf->setDirectory($self->{'directory'} . "/$id/configuration");

    my %confParams = _serviceConfParams(%params);

    my @ids = @{$serviceConf->ids()};
    if (@ids) {
        my $idConf = $ids[0];
        $confParams{'id'} = $idConf;
        $serviceConf->setRow(1, %confParams);
    } else {
        $serviceConf->addRow(%confParams);
    }

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
#	    protocol    - it can take one of these: any, tcp, udp,
#	                                            tcp/udp, grep, icmp
#	    sourcePort  - it can take:  "any"
#                                   An integer from 1 to 65536 -> 22
#                                   Two integers separated by colons -> 22:25
#	    destinationPort - same as source
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
#   string - id of the new created row
#
sub addMultipleService
{
    my ($self, %params) = @_;

    my $id = $self->addRow(_serviceParams(%params));

    unless (defined($id)) {
        throw EBox::Exceptions::Internal("Couldn't add name and description");
    }

    my $serviceConf = $self->parentModule()->model('ServiceConfigurationTable');
    unless (defined($serviceConf)) {
        throw EBox::Exceptions::Internal(
                    "Couldn't get ServiceConfigurationTable");
    }

    $serviceConf->setDirectory($self->{'directory'} . "/$id/configuration");

    for my $service (@{$params{'services'}}) {
        $service->{'internal'} = $params{'internal'};
        $service->{'readOnly'} = $params{'readOnly'};
        $serviceConf->addRow(_serviceConfParams(%{$service}));
    }

    return $id;
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

    my $name = $params{'name'};
    unless (defined($name)) {
        throw EBox::Exceptions::MissingArgument('name');
    }

    my $row = $self->findValue('name' => $name);
    unless (defined($row)) {
       throw EBox::Exceptions::DataNotFound('data' => 'service',
                                            'value' => 'name');
    }

    my $id = $row->id();
    $self->setRow(1, _serviceParams(%params), 'id' => $id);

    my $serviceConf = $self->parentModule()->model('ServiceConfigurationTable');
    unless (defined($serviceConf)) {
        throw EBox::Exceptions::Internal(
                    "Couldn't get ServiceConfigurationTable");
    }

    $serviceConf->setDirectory($self->{'directory'} . "/$id/configuration");
    my @ids = @{$serviceConf->ids()};
    unless (@ids or $params{'allowEmpty'}) {
        throw EBox::Exceptions::External(
                "This service has no protocols configured");
    }

    for my $row (@{$serviceConf->ids()}) {
        $serviceConf->removeRow($row);
    }

    for my $service (@{$params{'services'}}) {
        $service->{'internal'} = $params{'internal'};
        $service->{'readOnly'} = $params{'readOnly'};
        $serviceConf->addRow(_serviceConfParams(%{$service}));
    }

    return $id;
}

sub _serviceParams
{
    my (%params) = @_;

    my $name = delete $params{'name'};
    my $printableName = delete $params{'printableName'};
    unless ($name) {
        $name = $printableName;
    }
    unless ($printableName) {
        $printableName = $name;
    }

    my $description = delete $params{'description'};
    my $internal = $params{'internal'};
    my $readonly = $params{'readOnly'};

    return ('name' => $name,
            'printableName' => $printableName,
            'description' => $description,
            'internal' => $internal,
            'readOnly' => $readonly);
}

sub _serviceConfParams
{
    my (%params) = @_;

    my $protocol = delete $params{'protocol'};
    my $sourcePort = delete $params{'sourcePort'};
    my $destinationPort = delete $params{'destinationPort'};
    my $internal = $params{'internal'};
    my $readonly = $params{'readOnly'};

    my $sourcePortType;
    my $sourcePortFrom;
    my $sourcePortTo;
    my $sourceSinglePort;

    if ($sourcePort eq 'any') {
        $sourcePortType  = 'any';
    } elsif ($sourcePort =~ /^\d+$/) {
        $sourcePortType = 'single';
        $sourceSinglePort = $sourcePort;
    } elsif ($sourcePort =~ /^\d+:\d+/) {
        $sourcePortType = 'range';
        ($sourcePortFrom, $sourcePortTo) = split (/:/, $sourcePort);
    }

    my $destinationPortType;
    my $destinationPortFrom;
    my $destinationPortTo;
    my $destinationSinglePort;

    if ($destinationPort eq 'any') {
        $destinationPortType  = 'any';
    } elsif ($destinationPort =~ /^\d+$/) {
        $destinationPortType = 'single';
        $destinationSinglePort = $destinationPort;
    } elsif ($destinationPort =~ /^\d+:\d+/) {
        $destinationPortType = 'range';
        ($destinationPortFrom, $destinationPortTo) =
                          split (/:/, $destinationPort);
    }

    return ('protocol' => $protocol,
           'source_range_type' => $sourcePortType,
           'source_single_port' => $sourceSinglePort,
           'source_from_port' => $sourcePortFrom,
           'source_to_port' => $sourcePortTo,
           'destination_range_type' => $destinationPortType,
           'destination_single_port' => $destinationSinglePort,
           'destination_from_port' => $destinationPortFrom,
           'destination_to_port' => $destinationPortTo,
           'internal' => $internal,
           'readOnly' => $readonly);
}

sub _servicesHelp
{
    return __('A service is an abstraction of one or more network protocols '.
              'which can be used in other modules such as: firewall, traffic '.
              'shaping...');
}

sub serviceForAnyConnectionId
{
    my ($self, $protocol) = @_;
    my $name;
    if ($protocol eq 'tcp/udp') {
        $name = 'any';
    } elsif ($protocol eq 'tcp') {
        $name = 'any TCP';
    } elsif ($protocol eq 'udp') {
        $name = 'any UDP';
    }  else {
        return undef;
    }

    my $row = $self->findRow(name => $name);
    if ($row) {
        return $row->id();
    }

    return undef;
}

1;
