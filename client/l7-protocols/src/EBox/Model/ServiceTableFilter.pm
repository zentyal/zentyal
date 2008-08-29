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

# Class: EBox::Services::Model::ServiceTableFilter
#
#	This model is used as a proxy of <EBox::Services::Model::ServiceTable>
#	to show only rows which are not internal.
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

package EBox::Services::Model::ServiceTableFilter;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Types::HasMany;
use EBox::Sudo;
use EBox::Model::ModelManager;

use EBox::Exceptions::Internal;

use Clone qw(clone);

use strict;
use warnings;

use base 'EBox::Services::Model::ServiceTable';

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
    my ($self) = @_;

    my $table = clone $self->SUPER::_table();
    $table->{'tableName'} = 'ServiceTableFilter';
    
    my @header = grep {
                        $_->fieldName() ne 'internal'
                     } @{$table->{'tableDescription'}};
                     
    $table->{'tableDescription'} = \@header;

    $table->{'defaultController'} =
        '/ebox/Services/Controller/ServiceTableFilter';
    return $table;
}

sub rows
{
    my ($self) = @_;	

    my $model = EBox::Model::ModelManager->instance()->model('ServiceTable');
    my @rows;
    foreach my $row (@{$model->rows()}) {
    	my %newRow = %{$row};
        if ($row->{'valueHash'}->{'internal'}->{'value'}) {
            my @values;
            for my $value (@{$row->{'values'}}) {
                next if ($value->fieldName() eq 'internal');
                push (@values, $value);
            }
            $newRow{'values'} = \@values;
	    push (@rows, \%newRow);
        }
	
    }

    return \@rows;
}

1;
