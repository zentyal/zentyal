# Copyright (C) 2007 Warp Networks S.L.
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

# Class:
# 
#   EBox::DNS::Model::AliasTable
#
#   This class inherits from <EBox::Model::DataTable> and represents the
#   object table which basically contains domains names and a reference
#   to a member <EBox::DNS::Model::AliasTable>
#
#   
package EBox::DNS::Model::AliasTable;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;

use EBox::Types::DomainName;
use EBox::Sudo;

use Net::IP;

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

            new EBox::Types::DomainName
                            (
                                'fieldName' => 'alias',
                                'printableName' => __('Alias'),
                                'size' => '20',
                                'unique' => 1,
                                'editable' => 1
                             )
          );

    my $dataTable = 
        { 
            'tableName' => 'AliasTable',
            'printableTableName' => __('Alias'),
            'automaticRemove' => 1,
            'defaultController' => '/ebox/Dns/Controller/AliasTable',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'help' => __('Alias'),
            'printableRowName' => __('alias'),
            'sortedBy' => 'alias',
        };

    return $dataTable;
}

1;
