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
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
use strict;
use warnings;

package EBox::NUT::Model::UPSVariables;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;

use TryCatch::Lite;

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

    my $allVars = [];
    my $rwVars = [];
    try {
        $allVars = EBox::Sudo::root("upsc $label");
        $rwVars = EBox::Sudo::root("upsrw $label");
    } catch ($e) {
        my $text = join ('', @{$e->{error}});
        $self->setMessage("There was a problem reading variables. $text", 'warning');
    }

    my $vars = {};
    foreach my $line (@{$allVars}) {
        $line =~ s/\s*//g;
        not $line and next;
        my ($var, $value) = split(/:/, $line, 2);
        unless ( $var and
                (defined $value) and ($value ne '')) {
            EBox::debug("Unexpected upsc line: $line");
            next;
        }
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

sub ids
{
    my ($self) = @_;

    my $row = $self->parentRow();
    my $label = $row->valueByName('label');
    my $variables = $self->upsVariables($label);
    $self->{variables} = $variables;

    my $ids = [];
    foreach my $key (sort keys %{$variables}) {
        $variables->{$key} or
            next;
        push (@{$ids}, $key);
    }
    return $ids;
}

sub row
{
    my ($self, $id) = @_;

    my $var = '';
    my $value = '';

    my $variables = $self->{variables};
    if ($variables) {
        $var = $id;
        $value = $variables->{$id};
    } else {
        throw EBox::Exceptions::Internal('Not UPS variables loaded');
    }

    my $row = $self->_setValueRow(
        variable => $var,
        value => $value,
    );
    $row->setId($id);
    $row->setReadOnly(1);
    return $row;
}

# Method: precondition
#
#   Check if there is at least one vdomain.
#
# Overrides:
#
#       <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    my $mod = $self->parentModule();
    return $mod->isRunning();
}

# Method: preconditionFailMsg
#
#   Returns message to be shown on precondition fail
#
sub preconditionFailMsg
{
    my ($self) = @_;

    return __('The UPS service is not running. Ensure that changes are saved and the module enabled.');
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
        withoutActions     => 1,
    };

    return $dataTable;
}

1;
