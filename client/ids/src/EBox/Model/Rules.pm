# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::IDS::Model::Rules;

# Class: EBox::IDS::Model::Rules
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
#       <EBox::IDS::Model::Model> - the recently
#       created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;

}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    # If the GConf module is readonly, return current rows
    if ( $self->{'gconfmodule'}->isReadOnly() ) {
        return undef;
    }

    my $modIsChanged = EBox::Global->getInstance()->modIsChanged('ids');

    my @files = </etc/snort/rules/*.rules>;

    my @names;
    foreach my $file (@files) {
        my $slash = rindex ($file, '/');
        my $dot = rindex ($file, '.');
        my $name = substr ($file, ($slash + 1), ($dot - $slash - 1));
        push (@names, $name);
    }
    my %newNames = map { $_ => 1 } @names;

    my %currentNames =
        map { $self->row($_)->valueByName('name') => 1 } @{$currentRows};

    my $modified = 0;

    my @namesToAdd = grep { not exists $currentNames{$_} } @names;
    foreach my $name (@namesToAdd) {
        $self->add(name => $name, enabled => 1);
        $modified = 1;
    }

    # Remove old rows
    foreach my $id (@{$currentRows}) {
        my $row = $self->row($id);
        my $name = $row->valueByName('name');
        next if exists $newNames{$name};
        $self->removeRow($id);
        $modified = 1;
    }

    if ($modified and not $modIsChanged) {
        $self->{'gconfmodule'}->_saveConfig();
        EBox::Global->getInstance()->modRestarted('ids');
    }

    return $modified;
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
        new EBox::Types::Text(
            'fieldName' => 'name',
            'printableName' => __('Rule Set'),
            'unique' => 1,
            'editable' => 0),
        new EBox::Types::Boolean (
            'fieldName' => 'enabled',
            'printableName' => __('Enabled'),
            'defaultValue' => 1,
            'editable' => 1
        ),
    );

    my $dataTable =
    {
        tableName          => 'Rules',
        printableTableName => __('Rules'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        modelDomain        => 'IDS',
        printableRowName   => __('rule'),
        help               => __('help message'),
    };
    return $dataTable;
}

1;
