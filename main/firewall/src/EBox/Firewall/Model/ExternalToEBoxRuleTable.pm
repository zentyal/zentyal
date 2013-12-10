# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::Firewall::Model::ExternalToEBoxRuleTable
#
# This class describes the model used to store rules to access
# services running on Zentyal from internal networks.
#
# Inherits from <EBox::Firewall::Model::BaseRuleTable> to fetch
# the field description
#
use strict;
use warnings;

package EBox::Firewall::Model::ExternalToEBoxRuleTable;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;

use EBox::Types::Text;
use EBox::Types::Union::Text;
use EBox::Types::Boolean;
use EBox::Types::Select;
use EBox::Types::InverseMatchSelect;
use EBox::Types::IPAddr;
use EBox::Types::InverseMatchUnion;
use EBox::Sudo;

use base qw(EBox::Firewall::Model::BaseRuleTable) ;

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

    my $dataTable =
    {
        'tableName' => 'ExternalToEBoxRuleTable',
        'printableTableName' =>
          __('External networks to Zentyal'),
        'automaticRemove' => 1,
        'defaultController' =>
            '/Firewall/Controller/ExternalToEBoxRuleTable',
        'defaultActions' =>
            [	'add', 'del', 'move',  'editField', 'changeView', 'clone' ],
        'tableDescription' => $self->_fieldDescription('source' => 1),
        'menuNamespace' => 'Firewall/View/ExternalToEBoxRuleTable',
        'class' => 'dataTable',
        'order' => 1,
        'rowUnique' => 0,
        'printableRowName' => __('rule'),
    };

    return $dataTable;
}

sub permanentMessage
{
    return __('Be advised that adding rules in this section may compromise your network security as you may grant access from untrusted networks. Please do not use this unless you know what you are doing.');
}

sub permanentMessageType
{
    return 'warning';
}

1;
