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

# Class: EBox::L7Protocols::GroupProtocols
#   
#   FIXME
#

package EBox::L7Protocols::Model::GroupProtocols;

use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Select;
use EBox::Global;

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
    my $model = EBox::Global->modInstance('l7-protocols')->model('Protocols');
    my @protocols;
    for my $protocol (@{$model->rows()}) {
        push (@protocols, { value => $protocol->id(), 
                            printableValue => $protocol->valueByName('protocol')
                          });
    }
    return \@protocols;
}

sub _table
{

    my @tableHead = 
    ( 
        new EBox::Types::Select(
                    'fieldName' => 'protocol',
                    'printableName' => __('Protocol'),
                    'populate' => \&protocols,
                    'editable' => 1,
                    'help' => __('foo')
                )

    );

    my $dataTable = 
    { 
        'tableName' => 'GroupProtocols',
        'automaticRemove' => 1,
        'printableTableName' => __('Layer 7 grouped protocols'),
        'defaultController' =>
            '/ebox/L7-Protocols/Controller/GroupProtocols',
        'defaultActions' =>
            ['add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'menuNamespace' => 'Services/View/ServiceTable',
        'help' => '', # FIXME
        'printableRowName' => __('protocol'),
    };

    return $dataTable;
}

1;
