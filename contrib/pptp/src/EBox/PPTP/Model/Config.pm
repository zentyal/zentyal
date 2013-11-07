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

package EBox::PPTP::Model::Config;

use base 'EBox::Model::DataForm';

# Class: EBox::PPTP::Model::Config
#
#       Form to set the Config configuration for the RADIUS server
#

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Host;
use EBox::Types::IPNetwork;

use List::Util;

use constant START_ADDRESS_PREFIX => '192.168.';
use constant FROM_RANGE => 210;
use constant TO_RANGE => 250;

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
    my ($self) = @_;

    my @tableHeader =
      (
         new EBox::Types::IPNetwork(
             fieldName => 'network',
             printableName => __('VPN Network Address'),
             editable => 1,
             defaultValue  => $self->_defaultNetwork(),
             help => __('This address should be different from any other internal or VPN network.'),
             ),
         new EBox::Types::Host(
             fieldName => 'nameserver1',
             printableName => __('Primary Nameserver'),
             editable => 1,
             defaultValue  => $self->_primaryNS(),
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
        help               => __('PPTP VPN is used for connecting Microsoft ' .
                                 'Windows clients without any third party client ' .
                                 'and mobile devices like iPhone and Android.'),
    };

    return $dataTable;
}

sub _primaryNS
{
    my ($self) = @_;

    my $network = EBox::Global->modInstance('network');
    my $nsOne = $network->nameserverOne();

    ($nsOne) or return undef;
    return $nsOne;
}

sub _defaultNetwork
{
    my ($self) = @_;

    my $netMod = EBox::Global->modInstance('network');
    my @addresses;
    for my $iface (@{$netMod->allIfaces()}) {
        my $address = $netMod->ifaceAddress($iface);
        push (@addresses, $address) if ($address);
    }

    my $network;
    for my $postfix (FROM_RANGE .. TO_RANGE) {
        my $net = START_ADDRESS_PREFIX . $postfix;
        next if (List::Util::first {$_ =~ /^$net.*/ } @addresses);
        $network= "${net}.0/24";
        last;
    }

    return $network;
}

1;
