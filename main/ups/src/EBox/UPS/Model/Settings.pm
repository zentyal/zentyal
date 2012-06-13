# Copyright (C) 2012 eBox Technologies S. L.
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

package EBox::UPS::Model::Settings;

use strict;
use warnings;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::UPS::Types::DriverPicker;

use File::Slurp;

use constant DRIVER_LIST_FILE => '/usr/share/nut/driver.list';

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

sub _table
{
    my @tableDesc = (
        new EBox::Types::Text(
            fieldName => 'label',
            printableName => 'UPS label',
            editable => 1,
            unique => 1,
        ),
        new EBox::UPS::Types::DriverPicker(
                fieldName => 'driver',
                printableName => __('Driver'),
                editable     => 1,
                defaultValue => 'APC|||Back-UPS RS USB|||usbhid-ups',
                help => __('The manufacturer of your UPS.'),
        ),
    );

    my $dataForm = {
        tableName          => 'Settings',
        printableTableName => __('General configuration settings'),
        pageTitle          => __('UPS'),
        modelDomain        => 'UPS',
        defaultActions     => [ 'add', 'delete', 'editField', 'changeView' ],
        tableDescription   => \@tableDesc,
        help               => __('List of attached UPS'),
    };

    return $dataForm;
}

1;
