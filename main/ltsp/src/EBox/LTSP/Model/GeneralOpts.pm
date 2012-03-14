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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Class: EBox::LTSP::Model::GeneralOpts
#
#   TODO: Document class
#

package EBox::LTSP::Model::GeneralOpts;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Boolean;
use EBox::Types::IPAddr;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Types::Time;

sub new
{
        my $class = shift;
        my %parms = @_;

        my $self = $class->SUPER::new(@_);
        bless($self, $class);

        return $self;
}

sub _table
{

    my @fields =
    (
        new EBox::Types::Boolean(
            fieldName       => 'one_session',
            printableName   => __('Limit one session per user'),
            editable        => 1,
            defaultValue    => 0,
            help            => __('Default \'Disabled\''),
        ),
        new EBox::Types::Boolean(
            fieldName       => 'network_compression',
            printableName   => __('Network Compression'),
            editable        => 1,
            defaultValue    => 0,
            help            => __('Default \'Disabled\''),
        ),
        new EBox::Types::Boolean(
            fieldName       => 'local_apps',
            printableName   => __('Local applications'),
            editable        => 1,
            defaultValue    => 0,
            help            => __('Default \'Disabled\''),
        ),
        new EBox::Types::Boolean(
            fieldName       => 'local_dev',
            printableName   => __('Local devices'),
            editable        => 1,
            defaultValue    => 1,
            help            => __('Default \'Enabled\''),
        ),
        new EBox::Types::Boolean(
            fieldName       => 'autologin',
            printableName   => __('AutoLogin'),
            editable        => 1,
            defaultValue    => 0,
            help            => __('Default \'Disabled\''),
        ),
        new EBox::Types::Boolean(
            fieldName       => 'guestlogin',
            printableName   => __('Guest Login'),
            editable        => 1,
            defaultValue    => 0,
            help            => __('Default \'Disabled\''),
        ),
        new EBox::Types::Boolean(
            fieldName       => 'sound',
            printableName   => __('Sound'),
            editable        => 1,
            defaultValue    => 1,
            help            => __('Default \'Enabled\''),
        ),
        new EBox::Types::Text(
            fieldName       => 'kb_layout',
            printableName   => __('Keyboard Layout'),
            size            => 10,
            editable        => 1,
            defaultValue    => 'en',
        ),
        new EBox::Types::IPAddr(
            fieldName       => 'server',
            printableName   => __('Server'),
            editable        => 1,
            optional        => 1,
            help            => __('IP address of the server for "everything". ' .
                                  'If not set, it will be Zentyal.'),
        ),
        new EBox::Types::IPAddr(
            fieldName       => 'time_server',
            printableName   => __('Time Server'),
            editable        => 1,
            optional        => 1,
            help            => __('IP address of the time server. ' .
                                  'If not set, it will be undef.'),
        ),
        new EBox::Types::Union(
            fieldName      => 'shutdown',
            printableName  => __('Shutdown Time'),
            editable       => 1,
            subtypes       => [
                new EBox::Types::Union::Text(
                    fieldName       => 'none',
                    printableName   => __('None'),
                ),
                new EBox::Types::Time(
                    fieldName       => 'shutdown_time',
                    printableName   => __('At'),
                    editable        => 1,
                ),
            ],
            help            => __('Time when clients will be automatically shutdown.'),
        ),
    );

    my $dataTable =
    {
        tableName => 'GeneralOpts',
        printableTableName => __('General Options'),
        modelDomain => 'LTSP',
        defaultActions => ['add', 'del', 'editField', 'changeView' ],
        tableDescription => \@fields,
    };

    return $dataTable;
}

1;
