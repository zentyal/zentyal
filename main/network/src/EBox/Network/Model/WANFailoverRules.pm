# Copyright (C) 2009-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::Network::Model::WANFailoverRules;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Int;
use EBox::Types::Select;
use EBox::Types::HostIP;
use EBox::View::Customizer;
use EBox::Validate;
use EBox::Exceptions::External;
use Perl6::Junction qw(any);

use base 'EBox::Model::DataTable';

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub gatewayModel
{
    return EBox::Global->modInstance('network')->model('GatewayTable');
}

sub types
{
    return [
             {
               'value' => 'gw_ping',
               'printableValue' => __('Ping to gateway')
             },
             {
               'value' => 'host_ping',
               'printableValue' => __('Ping to host')
             },
             {
               'value' => 'http',
               'printableValue' => __('HTTP Request')
             },
           ];
}

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHead =
    (
        new EBox::Types::Select(
           'fieldName' => 'gateway',
           'printableName' => 'Gateway',
           'foreignModel' => \&gatewayModel,
           'foreignField' => 'name',
           'editable' => 1,
            ),
        new EBox::Types::Select(
           'fieldName' => 'type',
           'printableName' => __('Test type'),
           'populate' => \&types,
           'editable' => 1,
            ),
        new EBox::Types::HostIP(
           'fieldName' => 'host',
           'printableName' => __('Host IP address'),
           'editable' => 1,
           'optional' => 1,
           'optionalLabel' => 0,
            ),
        new EBox::Types::Int(
           'fieldName' => 'probes',
           'printableName' => __('Number of probes'),
           'defaultValue' => 6,
           'size' => 2,
           'min' => 1,
           'max' => 50,
           'editable' => 1,
            ),
        new EBox::Types::Int(
           'fieldName' => 'ratio',
           'printableName' => __('Required success ratio'),
           'trailingText' => '%',
           'defaultValue' => 40,
           'size' => 2,
           'min' => 1,
           'max' => 100,
           'editable' => 1,
            ),
    );

    my $dataTable =
    {
        'tableName' => 'WANFailoverRules',
        'printableTableName' => __('Test rules'),
        'defaultActions' => [ 'add', 'del', 'editField', 'clone', 'changeView' ],
        'modelDomain' => 'Network',
        'tableDescription' => \@tableHead,
        'class' => 'dataTable',
        'enableProperty' => 1,
        'defaultEnabledValue' => 1,
        'help' => __('You can define different rules to test if a gateway is working properly. If one of the test fails the gateway will be disabled. It will be enabled again when all tests are passed.'),
        'printableRowName' => __('rule'),
    };

    return $dataTable;
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer> to implement
#   a custom behaviour to enable and disable the host field
#   depending on the test type
#
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    my $fields = [ 'host' ];
    $customizer->setModel($self);
    $customizer->setOnChangeActions(
            { type =>
                {
                gw_ping   => { disable => $fields },
                host_ping => { enable  => $fields },
                http      => { enable  => $fields },
                }
            });
    return $customizer;
}

# Method: validateTypedRow
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    my $type = $allFields->{type}->value();

    return if $type eq 'gw_ping';

    my $host = $allFields->{host}->value();
    if (not $host) {
        throw EBox::Exceptions::MissingArgument($allFields->{host}->printableName);
    }
}

1;
