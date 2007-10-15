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

package EBox::CGI::TrafficShaping::Index;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;

# Constructor: new
#
#      Constructor for Index CGI
#
# Returns:
#
#      <EBox::CGI::TrafficShaping::Index> - the recently created
#      object
#
sub new
  {

    my $class = shift;

    my $self = $class->SUPER::new('title'    => __('Traffic Shaping Management'),
				  'template' => '/trafficshaping/index.mas',
				  @_);

    $self->{domain} = 'ebox-trafficshaping';
    bless( $self, $class );

    return $self;

  }

# No need to have parameters (optionalParameters and
# requiredParameters can be left empty)

# Method: masonParameters
#
#      Overrides <EBox::CGI::ClientBase::masonParameters>
#
sub masonParameters
  {

    my ($self) = @_;

    my $global = EBox::Global->getInstance();

    my $net = $global->modInstance('network');
    my $ts = $global->modInstance('trafficshaping');
    $ts->startUp;
    my $enoughInterfaces = $ts->enoughInterfaces();
    my $composite = $ts->composites()->[0];
    my $areGateways = undef;
    foreach my $iface (@{$net->ExternalIfaces()}) {
      # FIXME -> This should done by network -> Workaround to fix #373
      my $uploadRate = $ts->uploadRate($iface);
      if ( defined ($uploadRate) and
	   $uploadRate > 0 ) {
	$areGateways = 1;
      }
    }

    return [
	    enoughInterfaces => $enoughInterfaces,
	    areGateways      => $areGateways,
	    model            => $composite
	   ];

  }

1;
