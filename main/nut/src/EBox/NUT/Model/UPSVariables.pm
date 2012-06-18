# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::NUT::Model::UPSVariables;

use strict;
use warnings;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Types::Text;

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub upsVariables
{
    my ($self, $label) = @_;

    unless (defined $label) {
        throw EBox::Exceptions::MissingArgument('label');
    }
    my $allVars = EBox::Sudo::root("upsc $label");
    my $rwVars = EBox::Sudo::root("upsrw $label");

    my $vars = {};
    foreach my $line (@{$allVars}) {
        $line =~ s/\s*//g;
        my ($var, $value) = split(/:/, $line);
        $vars->{$var} = $value,
    }

    # Remove RW vars
    foreach my $line (@{$rwVars}) {
        if ($line =~ /^\[(.+)\]$/) {
            delete $vars->{$1};
        }
    }

    return $vars;
}

sub syncRows
{
    my ($self, $currentIds) = @_;

    my $modified = 0;

    my $row = $self->parentRow();
    my $label = $row->valueByName('label');
    my $variables = $self->upsVariables($label);

    foreach my $id (@{$currentIds}) {
        my $row = $self->row($id);
        my $var = $row->valueByName('variable');
        my $val = $row->elementByName('value');
        if (exists $variables->{$var}) {
            my $value = $variables->{$var};
            if ($value) {
                $val->setValue($value);
            } else {
                $val->setValue('---');
            }
            delete $variables->{$var};
        } else {
            $self->removeRow($id);
            $modified = 1;
        }
    }

    foreach my $key (keys %{$variables}) {
        my $value = $variables->{$key};
        $self->addRow(variable => $key,
                      value => $value,
                      readOnly => 1);
        $modified = 1;
    }
    return $modified;
}

sub _table
{
    my $tableHead = [
        new EBox::Types::Text(
            fieldName => 'variable',
            printableName => __('Variable'),
        ),
        new EBox::Types::Text(
            fieldName => 'value',
            printableName => __('Value'),
        ),
    ];

    my $dataTable = {
        tableName => 'UPSVariables',
        printableTableName => __('UPS Variables'),
        modelDomain => 'NUT',
        defaultActions => [ 'changeView' ],
        tableDescription => $tableHead,
        class => 'dataTable',
        printableRowName => __('variable'),
        insertPosition => 'back',
        sortedBy => 'variable',
        help => __('This is the list of the variables published by the UPS. ' .
                   'Some of them may be read only'),
    };

    return $dataTable;
}

1;
