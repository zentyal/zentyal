# Copyright (C) 2012-2013 Zentyal S. L.
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

package EBox::NUT::Model::UPS;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::Select;
use EBox::Types::HasMany;
use EBox::NUT::Types::DriverPicker;
use EBox::Exceptions::External;

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

sub upsList
{
    my ($self) = @_;

    my $list = [];
    foreach my $id (@{$self->ids()}) {
        my $ups = {};
        my $row = $self->row($id);
        $ups->{label}       = $row->valueByName('label');
        $ups->{data}        = $row->valueByName('driver');
        $ups->{port}        = $row->valueByName('port');
        $ups->{serial}      = $row->valueByName('serial');
        $ups->{description} = $row->valueByName('description');
        push (@{$list}, $ups);
    }
    return $list;
}

# Method: validateTypedRow
#
# Overrides:
#
#   <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    my $label = exists $changedFields->{label} ?
        $changedFields->{label}->value() : $allFields->{label}->value();
    if ($label =~ m/\s+/) {
        throw EBox::Exceptions::External(__("'Label' can not contain spaces"));
    }
}

sub _table
{
    my @tableDesc = (
        new EBox::Types::Text(
            fieldName => 'label',
            printableName => 'UPS label',
            editable => 1,
            unique => 1,
            help => __('The label to identify this UPS in case you define more than one'),
        ),
        new EBox::Types::Text(
            fieldName => 'description',
            printableName => __('Description'),
            editable => 1,
            optional => 1,
            help => __('Optional UPS description'),
        ),
        new EBox::NUT::Types::DriverPicker(
            fieldName => 'driver',
            printableName => __('Driver'),
            editable     => 1,
            allowUnsafeChars => 1,
            help => __('The manufacturer of your UPS.'),
        ),
        new EBox::Types::Select(
            fieldName => 'port',
            printableName => __('Port'),
            defaultValue => 'auto',
            populate => \&_ports,
            editable => 1,
            help => __('The port where the UPS is connected to (UPS on serial ports cannot be autodected)'),
        ),
        new EBox::Types::Text(
            fieldName => 'serial',
            printableName => 'Serial number',
            editable => 1,
            optional => 1,
            unique => 1,
            help => __('The UPS serial number, used to distingish between USB units'),
        ),
        new EBox::Types::HasMany(
            fieldName => 'variables',
            printableName => __('Settings'),
            foreignModel => 'nut/Variables',
            foreignModelIsComposite => 1,
            view => '/NUT/Composite/Variables',
            backView => '/NUT/View/UPS',
        ),
    );

    my $dataForm = {
        tableName          => 'UPS',
        printableTableName => __('Attached UPSs'),
        printableRowName   => __('UPS'),
        modelDomain        => 'NUT',
        defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => \@tableDesc,
        help               => __('List of locally attached UPS.'),
    };

    return $dataForm;
}

sub _ports
{
    return [
        { value => 'auto', printableValue => 'Autodetect' },
        { value => '/dev/ttyS0', printableValue => 'Serial 1' },
        { value => '/dev/ttyS1', printableValue => 'Serial 2' },
        { value => '/dev/ttyS2', printableValue => 'Serial 3' },
        { value => '/dev/ttyS3', printableValue => 'Serial 4' },
    ];
}

1;
