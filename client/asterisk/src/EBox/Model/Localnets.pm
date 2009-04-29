# Copyright (C) 2007 Warp Networks S.L.
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


package EBox::Asterisk::Model::Localnets;

# Class: EBox::Asterisk::Model::Localnets
#
#      Form to set the configuration settings for the localnets
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::IPAddr;
use EBox::Types::Text;

use Net::IP;

# Group: Public methods

# Constructor: new
#
#       Create the new Localnets model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Asterisk::Model::Localnets> - the recently created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}


# Method: validateTypedRow
#
#       Check the row to add or update if contains an existing network
#
# Overrides:
#
#       <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#       <EBox::Exceptions::InvalidData> - thrown if the network is not valid
#
sub validateTypedRow
{
    my ($self, $action, $changedFields) = @_;

    if ( exists $changedFields->{localnet} ) {
        my $net = new Net::IP($changedFields->{localnet}->printableValue());
        my $localnet = $net->ip().'/'.$net->mask();
        my $network = EBox::Global->modInstance('network');
        my $ifaces = $network->InternalIfaces();
        for my $iface (@{$ifaces}) {
            my $ifacenet = $network->ifaceNetwork($iface).'/'.$network->ifaceNetmask($iface);
            if ($localnet eq $ifacenet) {
                throw EBox::Exceptions::DataExists(
                    'data'  => __('local network'),
                    'value' => $changedFields->{localnet}->printableValue(),
                );
            }
        }
    }
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
       new EBox::Types::IPAddr(
                                fieldName     => 'localnet',
                                printableName => __('Local network'),
                                unique        => 1,
                                editable      => 1,
                               ),
       new EBox::Types::Text(
                                fieldName     => 'desc',
                                printableName => __('Description'),
                                size          => 24,
                                unique        => 0,
                                editable      => 1,
                                optional      => 1,
                               ),
      );

    my $dataTable =
    {
        tableName          => 'Localnets',
        printableTableName => __('Local networks'),
        printableRowName   => __('local network'),
        defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        modelDomain        => 'Asterisk',
    };

    return $dataTable;

}

1;
