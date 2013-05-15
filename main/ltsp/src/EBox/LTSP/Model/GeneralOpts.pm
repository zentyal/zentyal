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
use strict;
use warnings;

package EBox::LTSP::Model::GeneralOpts;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Boolean;
use EBox::Types::Select;
use EBox::Types::IPAddr;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Types::Time;
use EBox::Types::Int;

use utf8;

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# TODO: extract names from kdb/symbols/*
my $langs = {
    'ara'   => 'Arabic',
    'bd'    => 'Bengali',
    'bg'    => 'Български',
    'es'    => 'Español',
    'us'    => 'English',
    'ee'    => 'Eesti',
    'cz'    => 'Czech',
    'dk'    => 'Dansk',
    'de'    => 'Deutsch',
    'gr'    => 'ελληνικά',
    'ir'    => 'فارسی',
    'fr'    => 'Français',
    'hu'    => 'Magyar',
    'it'    => 'Italiano',
    'jp'    => '日本語',
    'lt'    => 'Lietuvių',
    'no'    => 'Norsk',
    'ne'    => 'Nederlands',
    'pl'    => 'Polski',
    'br'    => 'Português do Brasil',
    'pt'    => 'Português',
    'ro'    => 'Română',
    'ru'    => 'Русский',
    'se'    => 'Svenska',
    'th'    => 'ภาษาไทย',
    'tr'    => 'Türkçe',
    'ua'    => 'украї́нська',
    'cn'    => '汉字',
    'tw'    => '繁體中文',
};

sub _populateLayouts
{

    opendir(my $dh, '/usr/share/X11/xkb/symbols/');
    my @symbols = readdir($dh);

    my $array = [];
    foreach my $layout (sort @symbols) {
        if (defined $langs->{$layout}) {
            push (@{$array}, { value => $layout, printableValue => $langs->{$layout} });
        }
    }

    closedir $dh;
    return $array;
}

sub _table
{
    my $default = __('Default');
    my $enabled = __('Enabled');
    my $disabled = __('Disabled');

    my @fields =
    (
        new EBox::Types::Boolean(
            fieldName       => 'one_session',
            printableName   => __('Limit one session per user'),
            editable        => 1,
            defaultValue    => 0,
            help            => "$default: $disabled",
        ),
        new EBox::Types::Boolean(
            fieldName       => 'network_compression',
            printableName   => __('Network Compression'),
            editable        => 1,
            defaultValue    => 0,
            help            => "$default: $disabled",
        ),
        new EBox::Types::Boolean(
            fieldName       => 'local_apps',
            printableName   => __('Local applications'),
            editable        => 1,
            defaultValue    => 0,
            help            => "$default: $disabled",
        ),
        new EBox::Types::Boolean(
            fieldName       => 'local_dev',
            printableName   => __('Local devices'),
            editable        => 1,
            defaultValue    => 1,
            help            => "$default: $enabled",
        ),
        new EBox::Types::Boolean(
            fieldName       => 'autologin',
            printableName   => __('AutoLogin'),
            editable        => 1,
            defaultValue    => 0,
            help            => "$default: $disabled",
        ),
        new EBox::Types::Boolean(
            fieldName       => 'guestlogin',
            printableName   => __('Guest Login'),
            editable        => 1,
            defaultValue    => 0,
            help            => "$default: $disabled",
        ),
        new EBox::Types::Boolean(
            fieldName       => 'sound',
            printableName   => __('Sound'),
            editable        => 1,
            defaultValue    => 1,
            help            => "$default: $enabled",
        ),
        new EBox::Types::Select(
            fieldName       => 'kb_layout',
            printableName   => __('Keyboard Layout'),
            editable        => 1,
            populate        => \&_populateLayouts,
            defaultValue    => 'us',
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
            defaultValue    => 500,
            help            => __('Below this amount of RAM memory a Fat Client will behave as a Thin Client.'),
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
