# Copyright (C) 2009-2010 eBox Technologies S.L.
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

package EBox::IMProxy::Model::Rules;

# Class: EBox::IMProxy::Model::Rules
#
#   Class description
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Select;

# Group: Public methods

# Constructor: new
#
#       Create the new model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
# Returns:
#
#       <EBox::IMProxy::Model::Model> - the recently
#       created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;

}

sub objectModel
{
    return EBox::Global->modInstance('objects')->{'objectModel'};
}

sub decision
{
    my @options = (
        {
            'value' => 'allow',
            'printableValue' => __('Allow')
        },
        {
            'value' => 'block',
            'printableValue' => __('Block')
        }
    );
    return \@options;
}

# Group: Protected methods

# Method: _table
#
#       Model description
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader = (
        new EBox::Types::Union(
            'fieldName' => 'object',
            'printableName' => __('Object'),
            'subtypes' => [
                new EBox::Types::Union::Text(
                    'fieldName' => 'source_any',
                    'printableName' => __('Any source')),
                new EBox::Types::Select(
                    'fieldName' => 'source_object',
                    'printableName' => __('Source object'),
                    'foreignModel' => \&objectModel,
                    'foreignField' => 'name',
                    'editable' => 1),
            ],
            'unique' => 1,
            'editable' => 1),
        new EBox::Types::Select (
            'fieldName' => 'decision',
            'printableName' => __('Decision'),
            'populate' => \&decision,
            'HTMLViewer' => '/ajax/viewer/imDecisionViewer.mas',
            'editable' => 1
        ),
    );

    my $dataTable =
    {
        tableName          => 'Rules',
        printableTableName => __('Filtering rules'),
        defaultActions     => [ 'add', 'del', 'move',
                                'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        modelDomain        => 'IMProxy',
        order              => 1,
        printableRowName   => __('rule'),
        help               => __('help message'),
    };
    return $dataTable;
}

sub rules
{
    my ($self) = @_;

    my $objMod = EBox::Global->modInstance('objects');

    my @rules = map {
        my $row = $self->row($_);

        my $rule = {};

        my $obj = $row->valueByName('object');

        if ($obj eq 'source_any') {
            $rule->{'address'} = 'any';
        } else {
            my $addresses = $objMod->objectAddresses($obj);
            $rule->{'address'} = $addresses;
        }
        $rule->{'decision'} = $row->valueByName('decision');
        $rule;
    } @{ $self->ids() };

    return \@rules;
}

1;
