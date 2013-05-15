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

# Class: EBox::NTP::Model::Servers
#

use strict;
use warnings;

package EBox::NTP::Model::Servers;

use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Host;

use base 'EBox::Model::DataTable';

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
        new EBox::Types::Host(
            'fieldName' => 'server',
            'printableName' => __('Server'),
            'editable' => 1,
            'unique' => 1,
        ),
    );

    my $dataTable =
    {
        'tableName' => 'Servers',
        'printableTableName' => __('NTP Servers'),
        'printableRowName' => __('server'),
        'modelDomain' => 'NTP',
        'defaultActions' => [ 'add', 'del', 'editField', 'changeView', ],
        'tableDescription' => \@tableHead,
        'help' => __('Here you can add external NTP servers to synchronize with.'),
    };

    return $dataTable;
}

1;
