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

# Class: EBox::Network::Model::ServiceConfigurationTable
#
#   This class describes the data model used to store services.
#   That is, a set of abstractions for protocols and ports.
#
#   This model is intended to be used as 'hasMany' relationship
#   with model <EBox::Network::Model::ServiceTable>.
#
#   Let's see the data structure returned by printableValueRows()
#
#       [
#            {
#               'source' => 'any',
#               'protocol' => 'TCP',
#               'destination' => '22',
#               'id' => 'serv16'
#            }
#      ],
#
use strict;
use warnings;

package EBox::Network::Model::ServiceConfigurationTable;
use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::View::Customizer;

use EBox::Types::Select;
use EBox::Types::PortRange;
use EBox::Sudo;

use Perl6::Junction qw( any );



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
                 'value' => 'ah',
                 'printableValue' => 'AH'
                 },
                 {
                 'value' => 'esp',
                 'printableValue' => 'ESP'
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

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer> to implement
#   a custom behaviour to show and hide source and destination ports
#   depending on the protocol
#
#
sub viewCustomizer
{
    my ($self) = @_;
    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    $customizer->setOnChangeActions(
            { protocol =>
                {
                any => { disable => [qw/source destination/] },
                icmp => { disable => [qw/source destination/] },
                gre => { disable => [qw/source destination/] },
                esp => { disable => [qw/source destination/] },
                ah => { disable => [qw/source destination/] },
                tcp => { enable => [qw/source destination/] },
                udp => { enable => [qw/source destination/] },
                'tcp/udp' => { enable => [qw/source destination/] },
                }
                });
    return $customizer;
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
                         'help' => __('This field is usually set to any')
                         ),
                 new EBox::Types::PortRange(
                         'fieldName' => 'destination',
                         'printableName' => __('Destination port'),
                         'editable' => 1,
                         # FIXME: this usability improvement cannot be
                         # implemented because PortRange type cannot be
                         # optional, maybe we should fix viewCustomizer to
                         # automatically ignore hidden values even
                         # if not marked as optional
                         # 'defaultSelectedType' => 'single',
                         )
               );

        my $dataTable =
        {
                'tableName' => 'ServiceConfigurationTable',
                'printableTableName' => __('Service configuration'),
                'defaultController' =>
                        '/Network/Controller/ServiceConfigurationTable',
                'defaultActions' =>
                        ['add', 'del', 'move',  'editField', 'changeView', 'clone' ],
                'tableDescription' => \@tableHead,
                'menuNamespace' => 'Network/View/ServiceConfigurationTable',
                'HTTPUrlView' => 'Network/View/ServiceConfigurationTable',
                'class' => 'dataTable',
                'rowUnique' => 1,
                'printableRowName' => __('service'),
                'insertPosition' => 'back',
        };

        return $dataTable;
}

# Method: pageTitle
#
#   Overrides <EBox::Model::DataTable::pageTitle>
#   to show the name of the domain
sub pageTitle
{
    my ($self) = @_;

    my $parentRow = $self->parentRow();
    if (not $parentRow) {
        # workaround: sometimes with a logout + apache restart the directory
        # parameter is lost. (the apache restart removes the last directory used
        # from the models)
        EBox::Exceptions::ComponentNotExists->throw('Directory parameter and attribute lost');
    }

    return $parentRow->printableValueByName('printableName');
}

sub validateTypedRow
{
    my ($self, $action, $params_r, $all_r) = @_;
    if (($all_r->{source}->value() eq 'any') and
        ($all_r->{destination}->value() eq 'any') )  {
        my $protocol = $all_r->{protocol}->value();
        my $serviceTable =  $self->parentModule()->model('ServiceTable');
        my $anyServiceId = $serviceTable->serviceForAnyConnectionId($protocol);
        if ($anyServiceId) {
            # already exists 'any' service for this protocol
            if ($anyServiceId eq $self->parentRow()->id()) {
                # the service itself is any service
                return;
            }
            my $anyService = $serviceTable->row($anyServiceId)->valueByName('printableName');
            throw EBox::Exceptions::External(
                __x('If you want a service for any connections on this protocol, use the predefined service {ser}',
                    ser => $anyService
                   )
               )
        }
    }
}

1;

