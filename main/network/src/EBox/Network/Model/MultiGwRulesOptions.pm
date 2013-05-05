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

package EBox::Network::Model::MultiGwRulesOptions;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Boolean;

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
            fieldName => 'balanceTraffic',
            printableName => __('Enable'),
            editable      => 1,
            defaultValue => 0,

           )
    );

    my $dataTable =
    {
        'tableName' => 'MultiGwRulesOptions',
        'printableTableName' => __('Traffic balancing'),
        'defaultController' => '/Network/Controller/MultiGwRulesOptions',
        'defaultActions' =>
            [
                'editField', 'changeView'
            ],
        'tableDescription' => \@tableHead,
        'class' => 'dataForm',
        'order' => 1,
        'enableProperty' => 0,
        'defaultEnabledValue' => 1,
        help => __x('By enabling this feature, your traffic will be balanced amongst your gateways. That is, every new connection will be sent by a different gateway. You can choose which proportion of traffic goes through each gateway using the weight parameter of the gateway. You can change that value {openref}here{closeref}.{br}If you want to explicitily route traffic by a certain gateway, use the multigateway rules below',
                                openref => '<a href="/Network/View/GatewayTable">',
                                closeref => '</a>', br => '<br>'),
        'rowUnique' => 0,
        'printableRowName' => __('rule'),
    };

    return $dataTable;
}

sub precondition
{
    my $network = EBox::Global->modInstance('network');
    my $nGateways = @{$network->gateways()};
    return $nGateways >= 2;
}

1;
