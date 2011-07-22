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
    $self->{maxMem} = int ($totalMemory / 2);

    bless ( $self, $class );

    return $self;
}

# Group: Private methods

sub _populateOSTypes
{
    my ($self) = @_;

    return EBox::Global->modInstance('virt')->systemTypes();
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

    my $maxMem = $self->{maxMem};
    my $defaultMem = 512;
    if ($defaultMem > $maxMem) {
        $defaultMem = $maxMem;
    }
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
                            max           => $maxMem,
                            defaultValue  => $defaultMem,
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

# XXX: workaround for bad directory problem
sub parent
{
    my ($self) = @_;

    my $virt = $self->parentModule();
    my $parent = $virt->model('VirtualMachines');
    my $dir = $parent->directory();
    $dir =~ s{/keys$}{};
    $parent->setDirectory($dir);

    return $parent;
}

# XXX this method is only overriden to make the parentComposite fudge for view
# customizer possible
sub viewCustomizer
{
    my ($self) = @_;

    unless ($self->{viewCustomizer}) {
        # XXX workaround for parentComposite with viewCustomizer bug
        my $composite  = $self->{gconfmodule}->composite('VMSettings');
        $self->setParentComposite($composite);

        my $viewCustom = new EBox::View::Customizer();
        $viewCustom->setModel($self);
        $self->{viewCustomizer} = $viewCustom;
    }
    return $self->{viewCustomizer};
}

1;
