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

package EBox::L7Protocols::Model::Protocols;

use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Text;

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
            'fieldName' => 'protocol',
            'printableName' => __('Protocol'),
            'size' => '8',
            'unique' => 1,
            'editable' => 1
        ),
    );

    my $dataTable = 
    { 
        'tableName' => 'Protocols',
        'automaticRemove' => 1,
        'printableTableName' => __('Layer 7 protocols'),
        'defaultController' =>
            '/ebox/L7-Protocols/Controller/Protocols',
        'defaultActions' =>
            ['add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'menuNamespace' => 'Services/View/ServiceTable',
        'help' => '', # FIXME
        'printableRowName' => __('protocol'),
        'sortedBy' => 'protocol'
    };

    return $dataTable;
}

1;
