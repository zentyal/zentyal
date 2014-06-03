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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Class: EBox::Samba::Model::RecycleDefault
#
#   TODO: Document class
#

use strict;
use warnings;

package EBox::Samba::Model::RecycleDefault;

use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Port;

use base 'EBox::Model::DataForm';

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
            'fieldName' => 'enabled',
            'printableName' => __('Enable recycle bin'),
            'editable' => 1,
            'defaultValue' => 0
        ),
    );
    my $dataTable =
    {
        'tableName' => 'RecycleDefault',
        'printableTableName' => __('Recycle Bin default settings'),
        'modelDomain' => 'Samba',
        'defaultActions' => ['add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'help' => 'If Recycle Bin is enabled on a share, the deleted files on the share are stored on it instead of being deleted forever. This is the default setting that can be overrided by adding exceptions.',
        'pageTitle' => undef,
    };

    return $dataTable;
}

1;
