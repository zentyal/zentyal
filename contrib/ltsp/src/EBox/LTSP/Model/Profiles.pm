# Copyright (C) 2012-2013 Zentyal S.L.
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

# Class: EBox::LTSP::Model::Profiles
#
#   TODO: Document class
#

use strict;
use warnings;

package EBox::LTSP::Model::Profiles;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Validate qw(:all);

use EBox::Types::Text;
use EBox::Types::HasMany;

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
    my @fields =
    (
        new EBox::Types::Text(
            'fieldName' => 'name',
            'printableName' => __('Name'),
            'size' => '8',
            'unique' => 1,
            'editable' => 1,
            #'help' => __(''), # FIXME
        ),
        new EBox::Types::HasMany(
            'fieldName' => 'configuration',
            'printableName' => __('Configuration'),
            'foreignModel' => 'ltsp/ClientConfiguration',
            'foreignModelIsComposite' => 1,
            'view' => '/LTSP/Composite/ClientConfiguration',
            'backView' => '/LTSP/View/Profiles',
        ),
        new EBox::Types::HasMany(
            'fieldName' => 'clients',
            'printableName' => __('Clients'),
            'foreignModel' => 'ltsp/Clients',
            'view' => '/LTSP/View/Clients',
            'backView' => '/LTSP/View/Profiles',
        ),
    );

    my $dataTable =
    {
        'tableName' => 'Profiles',
        'printableTableName' => __('Profiles'),
        'printableRowName' => __('Profile'),
        'modelDomain' => 'LTSP',
        'defaultActions' => ['add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@fields,
        'sortedBy' => 'name',
        'enableProperty' => 1,
        'defaultEnabledValue' => 1,
        'help' => __('Profiles are used to apply a particular '
                     . 'configuration to a group of clients.'),
    };

    return $dataTable;
}

1;
