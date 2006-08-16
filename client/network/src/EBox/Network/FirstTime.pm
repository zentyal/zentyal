package EBox::Network::FirstTime;
# Description:
use strict;
use warnings;

use EBox::Network;
use EBox::Global;
use EBox::Gettext;


sub tasks
{
  return (
	      { completedCheck => \&ifaceConfigured, url => '/ebox/Network/FirstTime/Ifaces', desc => __('Configure network interfaces')   },
	      { completedCheck => \&DNSConfigured, url => '/ebox/Network/FirstTime/DNS', desc => __('Configure name servers')   },
	      { completedCheck => \&routeConfigured, url => '/ebox/Network/FirstTime/Routes', desc => __('Configure default gateway')   },
	 );
}


sub ifaceConfigured
{
  my $network = EBox::Global->modInstance('network');
  my $ifaceConfigured = grep { $network->ifaceOnConfig($_)  } @{ $network->ifaces() };
  return $ifaceConfigured > 0 ? 1 : undef;
}

sub DNSConfigured
{
  my $network = EBox::Global->modInstance('network');
  my $nameServers_r = $network->nameservers();
  return  @{$nameServers_r} > 0 ? 1 : undef;
}

sub routeConfigured
{
  my $network = EBox::Global->modInstance('network');
  my $gateway = $network->gateway();
  return  defined $gateway ? 1 : undef;
}

1;
