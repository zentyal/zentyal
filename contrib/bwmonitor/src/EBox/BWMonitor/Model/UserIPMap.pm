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

package EBox::BWMonitor::Model::UserIPMap;

use base 'EBox::Model::DataTable';

# Class: EBox::BWMonitor::Model::UserIPMap
#
#   Assigned IPs for each user
#

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::HostIP;

# Group: Public methods

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    bless($self, $class);
    return $self;
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
        new EBox::Types::Text(
            'fieldName' => 'username',
            'printableName' => __('Username'),
            'editable' => 0,
        ),
        new EBox::Types::HostIP(
            fieldName     => 'ip',
            printableName => __('IP'),
            unique        => 1,
            editable      => 0,
       ),
    );

    my $dataTable =
    {
        tableName          => 'UserIPMap',
        printableTableName => __('IPs assigned to users'),
        printableRowName   => __('useripmap'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        help               => __('List of IPs assigned to each user.'),
        modelDomain        => 'BWMonitor',
        rowUnique          => 1,
    };

    return $dataTable;
}

1;
