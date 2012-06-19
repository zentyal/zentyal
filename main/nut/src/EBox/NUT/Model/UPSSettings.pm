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

package EBox::NUT::Model::UPSSettings;

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
    my $rwVars = EBox::Sudo::root("upsrw $label");

    my $vars = {};

    my $var = undef;
    foreach my $line (@{$rwVars}) {
        if ($line =~ /^\s*$/) {
            $var = undef;
            next;
        }

        if ($line =~ /^\[(.+)\]$/) {
            $var = $1;
            unless ($vars->{$var}) {
                $vars->{$var} = {};
            }
            next;
        }

        next if $line =~ /^Type:/;

        if ($var and $line =~ /Value:\s+(.*)$/) {
            $vars->{$var}->{value} = $1;
            next;
        }

        if ($var) {
            chomp $line;
            $vars->{$var}->{description} = $line;
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
        push (@{$ids}, $key);
    }
    return $ids;
}

sub row
{
    my ($self, $id) = @_;

    my $setting = '';
    my $desc = '';
    my $value = '';

    my $variables = $self->{variables};
    if ($variables) {
        $setting = $id;
        $desc = $variables->{$id}->{description};
        $value = $variables->{$id}->{value};
    }

    my $row = $self->_setValueRow(
        setting => $setting,
        description => $desc,
        value => $value,
    );
    $row->setId($id);
    $row->setReadOnly(0);
    return $row;
}

sub setTypedRow
{
    my ($self, $id, $paramsRef, %optParams) = @_;

    my $label = $self->parentRow()->valueByName('label');
    my $var   = $paramsRef->{setting}->value();
    my $value = $paramsRef->{value}->value();

    # TODO Get the user when it is modelized
    EBox::debug("Set variable $var to $value");
    EBox::Sudo::root("upsrw -s '$var=$value' -u upsmon -p upsmon '$label'");

    $self->setMessage(__x('Setting {s} successfully updated. It may take some seconds to reflect the change.', s => $id));
}

sub _checkRowExist
{
    my ($self, $id, $text) = @_;

    my $variables = $self->{variables};
    unless ($variables and exists $variables->{$id}) {
        throw EBox::Exceptions::DataNotFound(
                data => $text,
                value => $id);
    }
}

#sub syncRowsDISABLE
#{
#    my ($self, $currentIds) = @_;
#
#    my $modified = 0;
#
#    my $row = $self->parentRow();
#    my $label = $row->valueByName('label');
#    my $variables = $self->upsVariables($label);
#
#    foreach my $id (@{$currentIds}) {
#        my $row = $self->row($id);
#        my $var = $row->valueByName('setting');
#        my $val = $row->elementByName('value');
#        if (exists $variables->{$var}) {
#            my $oldVar = $val->value();
#            my $value = $variables->{$var}->{value};
#            if ($value) {
#                if ($value ne $oldVar) {
#                    EBox::debug("Set variable $var to $value");
#                    $val->setValue($value);
##                    $row->store();
#                }
#            } else {
#                $val->setValue('');
##                $row->store();
#            }
#            delete $variables->{$var};
#        } else {
##            $self->removeRow($id);
##            $modified = 1;
#        }
#    }
#
#    foreach my $key (keys %{$variables}) {
#        my $value = $variables->{$key}->{value};
#        my $desc = $variables->{$key}->{description};
#        $self->addRow(setting => $key,
#                      description => $desc,
#                      value => $value);
#        $modified = 1;
#    }
#
#    return $modified;
#}

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
            fieldName => 'setting',
            printableName => __('Setting'),
        ),
        new EBox::Types::Text(
            fieldName => 'description',
            printableName => __('Description'),
            allowUnsafeChars => 1,
        ),
        new EBox::Types::Text(
            fieldName => 'value',
            printableName => __('Value'),
            editable => 1,
        ),
    ];

    my $dataTable = {
        tableName => 'UPSSettings',
        printableTableName => __('UPS Settings'),
        modelDomain => 'NUT',
        defaultActions => [ 'editField', 'changeView' ],
        tableDescription => $tableHead,
        class => 'dataTable',
        printableRowName => __('setting'),
        insertPosition => 'back',
        sortedBy => 'setting',
    };

    return $dataTable;
}

1;
