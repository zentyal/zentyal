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


package EBox::PPTP::Model::Config;

# Class: EBox::PPTP::Model::Config
#
#       Form to set the Config configuration for the RADIUS server
#

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Host;
use EBox::Types::IPNetwork;

# Group: Public methods

# Constructor: new
#
#       Create the new Config model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::PPTP::Model::Config> - the recently created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ($self, $class);

    return $self;
}

# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader =
      (
         new EBox::Types::IPNetwork(
             fieldName => 'network',
             printableName => __('VPN Network Address'),
             editable => 1,
             ),
         new EBox::Types::Host(
             fieldName => 'nameserver1',
             printableName => __('Primay Nameserver'),
             editable => 1,
             ),
         new EBox::Types::Host(
             fieldName => 'nameserver2',
             printableName => __('Secondary Nameserver'),
             editable => 1,
             optional => 1,
             ),
         new EBox::Types::Host(
             fieldName => 'wins1',
             printableName => __('Primary WINS'),
             editable => 1,
             optional => 1,
             ),
         new EBox::Types::Host(
             fieldName => 'wins2',
             printableName => __('Secondary WINS'),
             editable => 1,
             optional => 1,
             ),
      );

    my $dataTable =
    {
        tableName          => 'Config',
        printableTableName => __('General configuration'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataForm',
        help               => __("PPTP server configuration"),
        messages           => {
                                  update => __('PPTP server configuration updated'),
                              },
        modelDomain        => 'PPTP',
    };

    return $dataTable;
}

1;
