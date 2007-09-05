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

# Class: EBox::Services::Model::ServiceTable
#
#   This class describes the data model used to store services.
#   That is, a set of abstractions for protocols and ports.
#
#   This table stores basically the following fields:
#
#   name - service's name
#   description - service's description (optional)
#   configuration - hasMany relation with model
#                   <EBox::Services::ModelServiceConfigurationTable>
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
#            
#            
#     },
#     {
#        'id' => 'serv7867',
#        'name' => 'ftp',
#        'description' => 'File transfer protocol'
#        'configuration' => {
#            'model' => 'ServiceConfigurationTable',
#            'values' => [
#            {
#                'source' => 'any',
#                'protocol' => 'TCP',
#                'destination' => '21:22',
#                'id' => 'serv6891'
#            }
#            ],
#        },
#     }
#    ]

package EBox::Services::Model::ServiceTable;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Types::HasMany;
use EBox::Sudo;
use EBox::Model::ModelManager;

use EBox::Exceptions::Internal;


use strict;
use warnings;

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
        new EBox::Types::Text(
            'fieldName' => 'translationDomain',
            'printableName' => __('Domain'),
            'size' => '10',
            'optional' => 1,
            'hidden' => 1,
        ),
        new EBox::Types::Text(
            'fieldName' => 'name',
            'printableName' => __('Service name'),
            'localizable' => 1,
            'size' => '8',
            'unique' => 1,
            'editable' => 1
        ),
        new EBox::Types::Text(
            'fieldName' => 'description',
            'printableName' => __('Description'),
            'size' => '16',
            'editable' => 1,
            'optional' => 1,
        ),
        new EBox::Types::Boolean(
            'fieldName' => 'internal',
            'printableName' => __('Internal'),
            'hidden' => 1,
        ),
        new EBox::Types::HasMany (
            'fieldName' => 'configuration',
            'printableName' => __('Configuration'),
            'foreignModel' => 'ServiceConfigurationTable',
            'view' => '/ebox/Services/View/ServiceConfigurationTable',
        )
    );



    my $dataTable = 
    { 
        'tableName' => 'ServiceTable',
        'automaticRemove' => 1,
        'printableTableName' => __('Services'),
        'defaultController' =>
            '/ebox/Services/Controller/ServiceTable',
        'defaultActions' =>
            [	'add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'menuNamespace' => 'Services/View/ServiceTable',
        'class' => 'dataTable',
        'help' => __x('bbbb'),
        'printableRowName' => __('service')
    };

    return $dataTable;
}

# Method: _tailoredOrder
#
#        Overrides <EBox::Model::DataTable::_tailoredOrder>
#
#
sub _tailoredOrder # (rows)
{

    my ($self, $rows_ref) = @_;

    # Order rules per priority
    my @orderedRows = sort { $a->{valueHash}->{name}->value()
        cmp $b->{valueHash}->{name}->value() }
    @{$rows_ref};

    return \@orderedRows;

}

# Method: addService 
#
#   Add service to the services table. Note this method must exist
#   because we add services manually from other modules	
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
#
#   Example:
#
#        'protocol' => 'tcp',
#        'source' => 'any',
#       'destination' => '21:22',
sub addService 
{
    my ($self, %params) = @_;

    my $name = delete $params{'name'};
    my $description = delete $params{'description'};
    my $internal = delete $params{'internal'};
    my $readonly = delete $params{'readOnly'};
    
    my $id = $self->addRow('name' => $name, 
                           'description' => $description,
                           'internal' => $internal,
			   'readOnly' => $readonly);

    unless (defined($id)) {
        throw EBox::Exceptions::Internal("Couldn't add name and description");
    }

    my $protocol = delete $params{'protocol'};
    my $sourcePort = delete $params{'sourcePort'};
    my $destinationPort = delete $params{'destinationPort'};
    
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

    my $serviceConf = EBox::Model::ModelManager
                                       ->instance()
                                       ->model('ServiceConfigurationTable');
    unless (defined($serviceConf)) {
        throw EBox::Exceptions::Internal(
                    "Couldn't get ServiceConfigurationTable");
    }

	
    $serviceConf->setDirectory($self->{'directory'} . "/$id/configuration");
    $serviceConf->addRow('protocol' => $protocol, 
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

1;
