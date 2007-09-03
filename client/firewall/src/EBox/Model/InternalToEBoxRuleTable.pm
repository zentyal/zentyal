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

# Class: EBox::Firewall::Model::InternalToEBoxRuleTable
#
# This class describes the model used to store rules to access
# services running on eBox from internal networks
# 	
# Inherits from <EBox::Firewall::Model::BaseRuleTable> to fetch
# the field description
#
package EBox::Firewall::Model::InternalToEBoxRuleTable;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;

use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Types::Select;
use EBox::Types::InverseMatchSelect;
use EBox::Types::IPAddr;
use EBox::Types::InverseMatchUnion;
use EBox::Sudo;


use strict;
use warnings;


use base qw(EBox::Model::DataTable EBox::Firewall::Model::BaseRuleTable) ;



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
        'tableName' => 'InternalToEBoxRuleTable',
        'printableTableName' =>
          __('Filtering rules from internal networks to eBox'),
        'automaticRemove' => 1,
        'defaultController' =>
            '/ebox/Firewall/Controller/InternalToEBoxRuleTable',
        'defaultActions' =>
            [	'add', 'del', 'move',  'editField', 'changeView' ],
        'tableDescription' => $self->_fieldDescription('source' => 1),
        'menuNamespace' => 'Firewall/View/InternalToEBoxRuleTable',
        'order' => 1,
        'help' => __x(''),
        'printableRowName' => __('rule'),
    };

    return $dataTable;
}

1;
