# Copyright (C) 2006-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::NetWrappers::TestStub;

# Description:
#

use Test::MockObject;
use EBox::NetWrappers;
use EBox::Exceptions::DataNotFound;

my %fakeIfaces;
my %fakeRoutes;

sub fake
{
  Test::MockObject->fake_module('EBox::NetWrappers',
				iface_exists => \&iface_exists,
				list_ifaces  => \&list_ifaces,
				iface_is_up  => \&iface_is_up,
				iface_mac_address => \&iface_mac_address,
				iface_addresses => \&iface_addresses,
				iface_addresses_with_netmask => \&iface_addresses_with_netmask,
				list_routes  => \&list_routes,
				route_is_up  => \&route_is_up,
			       );

}

sub unfake
{
  delete $INC{'EBox/NetWrappers.pm'};
  eval 'use EBox::NetWrappers';
  $@ and die "Error reloading EBox::NetWrappers: $@";
}

sub setFakeIfaces
{
  my ($fakeIfaces_r) = @_;
  %fakeIfaces = %{$fakeIfaces_r};
}

sub fakeIfaces
{
  return \%fakeIfaces;
}

sub setFakeRoutes
{
  my ($fakeRoutes_r) = @_;
  %fakeRoutes = %{$fakeRoutes_r};
}

sub fakeRoutes
{
  return \%fakeRoutes;
}

# fake methods:
sub iface_exists
{
  my ($iface) = @_;
  return exists $fakeIfaces{$iface};
}

sub list_ifaces
{
  return sort keys %fakeIfaces;
}

sub iface_is_up
{
  my ($iface) = @_;
  return _ifacePropierty($iface, 'up');
}

sub iface_mac_address
{
  my ($iface) = @_;
  return _ifacePropierty($iface, 'mac_address');
}

sub iface_addresses
{
  my ($iface) = @_;
  my $address_r =  _ifacePropierty($iface, 'address') ;
  return keys %{ $address_r };
}

sub iface_addresses_with_netmask
{
  my ($iface) = @_;
  return _ifacePropierty($iface, 'address');
}

sub _ifacePropierty
{
  my ($iface, $propierty) = @_;

  unless (exists $fakeIfaces{$iface}) {
      throw EBox::Exceptions::DataNotFound(
						data => 'Interface',
						value => $iface);
  }

  unless (exists $fakeIfaces{$iface}->{$propierty} ) {
    die "You had not setted a $propierty propierty for the fake iface $iface";
  }

  return $fakeIfaces{$iface}->{$propierty};
}

sub list_routes
{
  my @routes;
  while (my ($dest, $router) = each %fakeRoutes) {
    push @routes, { network => $dest,  router => $router };
  }
  return @routes;
}

sub route_is_up
{
  my ($network, $router) = @_;

  if (exists $fakeRoutes{$network}) {
    if ($fakeRoutes{$network} eq $router) {
      return 1;
    }
  }

  return undef;
}

1;
