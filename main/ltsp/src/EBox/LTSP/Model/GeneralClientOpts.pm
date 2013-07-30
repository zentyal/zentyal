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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Class: EBox::LTSP::Model::GeneralClientOpts
#
#   TODO: Document class
#

use strict;
use warnings;

package EBox::LTSP::Model::GeneralClientOpts;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Select;
use EBox::Types::IPAddr;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Types::Time;
use EBox::Types::Int;

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

#
#   Callback function to fill out the values that can
#   be picked from the <EBox::Types::Select> field module
#
# Returns:
#
#   Array ref of hash refs containing the 'value' and the 'printableValue' for
#   each select option
#
sub _select_options
{
    return [
             {
               value => 'default',
               printableValue => __('Default'),
             },
             {
               value => 'True',
               printableValue => __('Enabled'),
             },
             {
               value => 'False',
               printableValue => __('Disabled'),
             },
    ];
}

sub _table
{
    my @fields =
    (
        new EBox::Types::Select(
            fieldName       => 'local_apps',
            printableName   => __('Local applications'),
            populate        => \&_select_options,
            editable        => 1,
        ),
        new EBox::Types::Select(
            fieldName       => 'local_dev',
            printableName   => __('Local devices'),
            populate        => \&_select_options,
            editable        => 1,
        ),
        new EBox::Types::Select(
            fieldName       => 'autologin',
            printableName   => __('AutoLogin'),
            populate        => \&_select_options,
            editable        => 1,
        ),
        new EBox::Types::Select(
            fieldName       => 'guestlogin',
            printableName   => __('Guest Login'),
            populate        => \&_select_options,
            editable        => 1,
        ),
        new EBox::Types::Select(
            fieldName       => 'sound',
            printableName   => __('Sound'),
            populate        => \&_select_options,
            editable        => 1,
        ),
        new EBox::Types::IPAddr(
            fieldName       => 'time_server',
            printableName   => __('Time Server'),
            editable        => 1,
            optional        => 1,
            help            => __('IP address of the time server.'),
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
            help => __('Time when clients will be automatically shutdown.'),
        ),
        new EBox::Types::Int(
            fieldName       => 'fat_ram_threshold',
            printableName   => __('Fat Client RAM Threshold (MB)'),
            editable        => 1,
            optional        => 1,
            help            => __('Below this amount of RAM memory a Fat Client will behave as a Thin Client.'),
        ),
    );

    my $dataTable =
    {
        tableName => 'GeneralClientOpts',
        printableTableName => __('General options'),
        modelDomain => 'LTSP',
        defaultActions => ['add', 'del', 'editField', 'changeView' ],
        tableDescription => \@fields,
        help => __('When an option is set to \'Default\' the global value for that option will be used.'),
    };

    return $dataTable;
}

1;
