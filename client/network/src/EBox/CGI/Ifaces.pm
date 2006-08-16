# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::CGI::Network::Ifaces;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('Network interfaces'),
				      'template' => '/network/ifaces.mas',
				      @_);
	$self->{domain} = 'ebox-network';
	bless($self, $class);
	return $self;
}

sub _process
{
	my $self = shift;
	$self->{params} = $self->masonParameters();
}


sub masonParameters
{
  my ($self) = @_;

  my $net = EBox::Global->modInstance('network');
  my $ifname = $self->param('iface');
  ($ifname) or $ifname = '';

  my $tmpifaces = $net->ifaces();
  my $iface = {};
  if ($ifname eq '') {
    $ifname = @{$tmpifaces}[0];
  }

  my @params = ();
	
  my @ifaces = ();

  foreach (@{$tmpifaces}) {
    my $ifinfo = {};
    $ifinfo->{'name'} = $_;
    $ifinfo->{'alias'} = $net->ifaceAlias($_);
    push(@ifaces,$ifinfo);
    ($_ eq $ifname) or next;
    $iface->{'name'} = $_;
    $iface->{'alias'} = $net->ifaceAlias($_);
    $iface->{'method'} = $net->ifaceMethod($_);
    if ($net->ifaceIsExternal($_)) {
      $iface->{'external'} = "yes";
    } else {
      $iface->{'external'} = "no";
    }
    if ($net->ifaceMethod($_) eq 'static') {
      $iface->{'address'} = $net->ifaceAddress($_);
      $iface->{'netmask'} = $net->ifaceNetmask($_);
      $iface->{'virtual'} = $net->vifacesConf($_);
    } elsif ($net->ifaceMethod($_) eq 'trunk') {
      push(@params, 'vlans' => $net->ifaceVlans($_));
    }
  }

  push(@params, 'iface' => $iface);
  push(@params, 'ifaces' => \@ifaces);

  return \@params;
}

1;
