# Copyright (C) 2009 eBox Technologies S.L.
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


package EBox::Network::Model::WANFailoverRules;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Int;
use EBox::Types::Select;
use EBox::Types::Host;
use EBox::View::Customizer;
use EBox::Validate;
use EBox::Exceptions::External;
use Perl6::Junction qw(any);

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
               'value' => 'dns',
               'printableValue' => __('DNS resolve')
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
        new EBox::Types::Host(
           'fieldName' => 'host',
           'printableName' => __('Host'),
           'editable' => 1,
           'optional' => 1,
            ),
        new EBox::Types::Int(
           'fieldName' => 'probes',
           'printableName' => __('Number of probes'),
           'defaultValue' => 10,
           'size' => 2,
           'min' => 1,
           'max' => 50,
           'editable' => 1,
            ),
        new EBox::Types::Int(
           'fieldName' => 'ratio',
           'printableName' => __('Required success ratio'),
           'trailingText' => '%',
           'defaultValue' => 75,
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
        'defaultActions' => [ 'add', 'del', 'editField', 'changeView' ],
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
                dns       => { enable  => $fields },
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

    my $host = $allFields->{host}->value();
    my $type = $allFields->{type}->value();

# FIXME: Temporal workaround until failover works with DHCP and PPPoE
#    if ($type eq 'gw_ping') {
        my $gwName = $allFields->{gateway}->value();
        my $network = EBox::Global->modInstance('network');
        my $gw = $network->model('GatewayTable')->row($gwName);
        my $iface = $gw->valueByName('interface');

#        if ($network->ifaceMethod($iface) eq 'ppp') {
#            throw EBox::Exceptions::External(__('Ping to gateway not available on PPPoE interfaces, select ping to host instead'));
#        }

#        return;
#    }
        if ($network->ifaceMethod($iface) eq any('ppp', 'dhcp')) {
            throw EBox::Exceptions::External(__('WAN Failover is only available for static interfaces'));
        }

    unless (EBox::Validate::checkHost($host)) {
        throw EBox::Exceptions::External(__('Invalid value for Host'));
    }
}

1;
