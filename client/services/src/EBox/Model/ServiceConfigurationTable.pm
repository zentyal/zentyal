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

# Class: EBox::Services::Model::ServiceConfigurationTable
#
#   This class describes the data model used to store services.
#   That is, a set of abstractions for protocols and ports.
#
#   This model is intended to be used as 'hasMany' relationship
#   with model <EBox::Services::Model::ServiceTable>.
#
#   Let's see the data structure returned by printableValueRows()
#
#	[
#            {
#               'source' => 'any',
#               'protocol' => 'TCP',
#               'destination' => '22',
#               'id' => 'serv16'
#            }
#      ],
#   
package EBox::Services::Model::ServiceConfigurationTable;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;

use EBox::Types::Select;
use EBox::Types::PortRange;
use EBox::Sudo;


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

sub protocols 
{
        my ($self) = @_;


        my  @options =
                (
                 {
                 'value' => 'tcp/udp',
                 'printableValue' => 'TCP/UDP'
                 },
                 {
                 'value' => 'tcp',
                 'printableValue' => 'TCP'
                 },
                 {
                 'value' => 'udp',
                 'printableValue' => 'UDP'
                 },
                 {
                 'value' => 'gre',
                 'printableValue' => 'GRE'
                 },
                 {
                 'value' => 'icmp',
                 'printableValue' => 'ICMP'
                 },
                 {
                 'value' => 'any',
                 'printableValue' => 'Any'
                 }
        );

        return \@options;

}

sub _table
{
        my @tableHead = 
                ( 
                 new EBox::Types::Select(
                         'fieldName' => 'protocol',
                         'printableName' => __('Protocol'),
			 'populate' => \&protocols,
                         'editable' => 1
                         ),
                 new EBox::Types::PortRange(
                         'fieldName' => 'source',
                         'printableName' => __('Source port'),
                         'editable' => 1,
                         ),
                 new EBox::Types::PortRange(
                         'fieldName' => 'destination',
                         'printableName' => __('Destination port'),
                         'editable' => 1,
                         )
               );



        my $dataTable = 
        { 
                'tableName' => 'ServiceConfigurationTable',
                'printableTableName' => __('Service configuration'),
                'defaultController' =>
                        '/ebox/Services/Controller/ServiceConfigurationTable',
                'defaultActions' =>
                        [	'add', 'del', 'move',  'editField', 'changeView' ],
                'tableDescription' => \@tableHead,
                'menuNamespace' => 'Services/View/ServiceConfigurationTable',
                'class' => 'dataTable',
                'help' => '', # FIXME
                'printableRowName' => __('service'),
        };

        return $dataTable;
}

# Method: validateRow
#
#      Override <EBox::Model::DataTable::validateRow> method
#
sub validateTypedRow()
{
    my ($self, $action, $parms)  = @_;

    if ($action eq 'add' or $action eq 'update') {
    	return unless (exists $parms->{'protocol'});
        my $type = $parms->{'protocol'}->value();
        if ($type eq 'gre' or $type eq 'icmp' or $type eq 'any') {
            my $source = $parms->{'source'};
            my $destination = $parms->{'destination'};
            for my $port ($source, $destination) {
                if ($port->single() or $port->from() or $port->to()) {
                    throw EBox::Exceptions::External(
                        __('This protocol does not use ports'));
                }
            }
        }
    }
}

1;

