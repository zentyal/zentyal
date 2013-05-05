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

# Class: EBox::LTSP::Model::OtherOpts
#
#   TODO: Document class
#

use strict;
use warnings;

package EBox::LTSP::Model::OtherClientOpts;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Validate qw(:all);

use EBox::Types::Text;

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
            'fieldName' => 'option',
            'printableName' => __('Option'),
            'unique' => 1,
            'editable' => 1,
        ),

        new EBox::Types::Text(
            'fieldName' => 'value',
            'printableName' => __('Value'),
            'editable' => 1,
        ),
    );

    my $dataTable =
    {
        'tableName' => 'OtherClientOpts',
        'printableTableName' => __('Other Options'),
        'printableRowName' => __('Option'),
        'modelDomain' => 'LTSP',
        'defaultActions' => ['add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@fields,
        'sortedBy' => 'option',
        'enableProperty' => 1,
        'defaultEnabledValue' => 1,
        'help' => __('Each option should be an LTSP option (lts.conf file).'),
    };

    return $dataTable;
}

1;
