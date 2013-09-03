# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::Virt::Model::SystemSettings;

use base 'EBox::Model::DataForm';

# Class: EBox::Virt::Model::SystemSettings
#
#       Form to set the System Settings for a Virtual Machine.
#

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
    return sub { $self->parentModule()->systemTypes() };
}

sub _populateArchitectures
{
    my ($self) = @_;
    return sub {$self->parentModule()->architectureTypes()};
}

sub _hideArchitectureSelector
{
    my ($self) = @_;
    return $self->parentModule()->usingVBox();
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
                               populate      => $self->_populateOSTypes,
                               editable      => 1,
                              ),
       new EBox::Types::Select(
                               fieldName     => 'arch',
                               printableName => __('Architecture'),
                               populate      => $self->_populateArchitectures,
                               hidden        => $self->_hideArchitectureSelector,
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

    if ($self->parentModule()->usingVBox()) {
       push (@tableHeader, new EBox::Types::Boolean(
                                fieldName     => 'manageonly',
                                printableName => __('Manage only'),
                                editable      => 1,
                                help          => __('Configuration will no longer be overwritten after activating this and the machine should be directly edited from VirtualBox GUI or using the vboxmanage command'),
                                defaultValue  => 0));
    }

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

# TODO: It would be great to have something like this implemented at framework level
# for all the models
sub isEqual
{
    #my ($self, $other) = @_;
    my ($self, $vmRow) = @_;

    my $virtRO = EBox::Global->getInstance(1)->modInstance('virt');

    my $this = $self->row();
    #$other = $other->row();

    my $thisMemory = $this->valueByName('memory');
    #my $otherMemory = $other->valueByName('memory');
    my $otherMemory = $virtRO->get_string("VirtualMachines/keys/$vmRow/settings/SystemSettings/keys/memory");
    if (defined ($thisMemory) and defined ($otherMemory)) {
        return 0 unless ($thisMemory eq $otherMemory);
    }

    my $thisOS = $this->valueByName('os');
    #my $otherOS = $other->valueByName('os');
    my $otherOS = $virtRO->get_string("VirtualMachines/keys/$vmRow/settings/SystemSettings/keys/os");
    if (defined ($thisOS) and defined ($otherOS)) {
        return 0 unless ($thisOS eq $otherOS);
    }

    return 1;
}

sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);

    $customizer->setHTMLTitle([]);

    return $customizer;
}

1;
