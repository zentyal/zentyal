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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Class: EBox::NTP::Model::Settings
#

use strict;
use warnings;

package EBox::NTP::Model::Settings;

use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Boolean;

use base 'EBox::Model::DataForm';

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
    my @tableHead =
    (
        new EBox::Types::Boolean(
            'fieldName' => 'sync',
            'printableName' => __('Enable synchronization with external servers'),
            'editable' => 1,
            'defaultValue' => 1
        ),
    );

    my $dataTable =
    {
        'tableName' => 'Settings',
        'printableTableName' => 'NTP',
        'modelDomain' => 'NTP',
        'defaultActions' => [ 'add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'help' => __('Here you can enable or disable time synchronization with external servers. You should remember to set up your timezone to have synchronization behaving correctly.'),
    };

    return $dataTable;
}

1;
