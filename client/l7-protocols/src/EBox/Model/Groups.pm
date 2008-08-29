# Copyright (C) 2008 eBox technologies
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

# Class: EBox::L7Protocols::Protocols
#   
#   FIXME
#

package EBox::L7Protocols::Model::Groups;

use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Text;
use EBox::Types::HasMany;

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
            'fieldName' => 'group',
            'printableName' => __('Group'),
            'size' => '8',
            'unique' => 1,
            'editable' => 1
        ),
        new EBox::Types::HasMany (
            'fieldName' => 'protocols',
            'printableName' => __('protocols'),
            'foreignModel' => 'GroupProtocols',
            'view' => '/ebox/L7-Protocols/View/GroupProtocols',
        )

    );

    my $dataTable = 
    { 
        'tableName' => 'Groups',
        'automaticRemove' => 1,
        'pageTitle' => __('Application content based grouped protocols'),
        'printableTableName' => __('List of groups'),
        'defaultController' =>
            '/ebox/L7-Protocols/Controller/Groups',
        'defaultActions' =>
            ['add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'help' => _helpL7(),
        'printableRowName' => __('group'),
        'sortedBy' => 'group',
    };

    return $dataTable;
}

sub _helpL7 
{
    return __('Here you can modify and create new groups of application ' .
              'content based protocols');
}

1;
