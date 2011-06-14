# Copyright (C) 2011 eBox Technologies S.L.
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

package EBox::Virt::Model::SystemSettings;

# Class: EBox::Virt::Model::SystemSettings
#
#       Form to set the System Settings for a Virtual Machine.
#

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Int;

# Group: Public methods

# Constructor: new
#
#       Create the new NAT model.
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Virt::Model::NAT> - the recently created model.
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    my $totalMemory = `free -m | awk 'NR==2 { print \$2 }'`;
    $self->{maxMem} = $totalMemory / 2;

    bless ( $self, $class );

    return $self;
}

# Group: Private methods

sub _populateOSTypes
{
    # FIXME: This is VBox-specific, we need to implement it using
    # the AbstractBackend
    my $output = `vboxmanage list ostypes`;
    my @lines = split ("\n", $output);

    my @values;
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        my ($id) = $line =~ /^ID:\s+(.*)/;
        if ($id) {
            $line = $lines[++$i];
            my ($desc) = $line =~ /^Description:\s+(.*)/;
            if ($desc) {
                push (@values, { value => $id, printableValue => $desc });
                $i++; # Skip blank line
            }
        }
    }
    return \@values;
}

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableHeader = (
       new EBox::Types::Select(
                               fieldName     => 'os',
                               printableName => __('Operating System'),
                               populate      => \&_populateOSTypes,
                               editable      => 1,
                              ),
       new EBox::Types::Int(
                            fieldName     => 'memory',
                            printableName => __('Base Memory'),
                            editable      => 1,
                            min           => 1,
                            max           => $self->{maxMem},
                            defaultValue  => 512,
                           ),
    );

    my $dataTable =
    {
        tableName          => 'SystemSettings',
        printableTableName => __('System Settings'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataForm',
        help               => __('Here you can define the basic hardware configuration of the machine'),
        modelDomain        => 'Virt',
    };

    return $dataTable;
}

1;
