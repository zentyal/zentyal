# Copyright (C)
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Class: EBox::LTSP::Model::AvailableImages
#
#   TODO: Document class
#

package EBox::LTSP::Model::AvailableImages;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Validate qw(:all);

use EBox::Types::Select;
use EBox::Types::Boolean;

sub new
{
        my $class = shift;
        my %parms = @_;

        my $self = $class->SUPER::new(@_);
        bless($self, $class);

        return $self;
}

# Method: populate_architecture
#
#   Callback function to fill out the values that can
#   be picked from the <EBox::Types::Select> field architecture
#
# Returns:
#
#   Array ref of hash refs containing:
#
sub populate_architecture
{
    return [
        {
            value => 'i386',
            printableValue => __('32 bits'),
        },
        {
            value => 'amd64',
            printableValue => __('64 bits'),
        },
    ];
}

sub _table
{

    my @fields =
    (

        new EBox::Types::Select(
            'fieldName' => 'architecture',
            'printableName' => __('Architecture'),
            'populate' => \&populate_architecture,
            'editable' => 0,
        ),

        new EBox::Types::Boolean(
            'fieldName' => 'fat',
            'printableName' => __('Fat Image'),
            'editable' => 0,
        ),
    );

    my $dataTable =
    {
        'tableName' => 'AvailableImages',
        'printableTableName' => __('Available Images'),
        'printableRowName' => __('Image'),
        'modelDomain' => 'LTSP',
        'defaultActions' => [ 'editField', 'changeView' ],
        'tableDescription' => \@fields,
        'help' => __('Images already created.'),
    };

    return $dataTable;
}

sub Viewer
{
    return '/ajax/tableBodyWithoutActions.mas';
}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#   to pre-add module rows.
sub syncRows
{
    my ($self, $currentRows)  = @_;

    # empty table
    foreach my $id (@{$currentRows}) {
        $self->removeRow($id, 1);
    }

    for my $arch (('i386', 'amd64')) {
        if ( -f "/opt/ltsp/images/$arch.img" ) {
            $self->add( architecture => $arch, fat => 0 );
        }
        if ( -f "/opt/ltsp/images/fat-$arch.img" ) {
            $self->add( architecture => $arch, fat => 1 );
        }
    }

    return 1;
}

1;
