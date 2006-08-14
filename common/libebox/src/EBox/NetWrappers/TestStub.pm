package EBox::NetWrappers::TestStub;
# Description:
# 
use strict;
use warnings;
use Test::MockModule;
use EBox::NetWrappers;

my %fakeIfaces;
my %fakeRoutes;

my $fakedModule;

sub fake
{
  $fakedModule = new Test::MockModule('EBox::NetWrappers');

				$fakedModule->mock(iface_exists => \&iface_exists);
				$fakedModule->mock(list_ifaces  => \&list_ifaces);
				$fakedModule->mock(iface_is_up  => \&iface_is_up);
				$fakedModule->mock(iface_mac_address => \&iface_mac_address);
				$fakedModule->mock(iface_addresses => \&iface_addresses);
				$fakedModule->mock(iface_addresses_with_netmask => \&iface_addresses_with_netmask);
				$fakedModule->mock(list_routes  => \&list_routes);
				$fakedModule->mock(route_is_up  => \&route_is_up);

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
  return keys %fakeIfaces;
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
