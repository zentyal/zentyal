# Copyright (C) 2006 Warp Networks S.L.
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

package EBox::TrafficShaping::QueueDiscipline::SFQ;

use strict;
use warnings;

# Its parent class is QueueDiscipline
use base 'EBox::TrafficShaping::QueueDiscipline::Abstract';

# Constructor: new
#
#       Constructor for SFQ (Stochastic Fair Queuing) class. This
#       queue discipline has N arbitrary queues where a *flow* is
#       entered through a hash function. The dequeue action is done in
#       a Round-Robin fashion.
#
# Parameters :
#
#       pertub - Periodicity in seconds of hash function alteration
#                (Optional)
#       quantum - Amount of data in kilobytes a stream is allowed to
#                 dequeue before next  queue gets a turn. Defaults to one MTU-sized
#                 packet. Do not set this parameter below the MTU! (Optional)
# Returns:
#
#      A recently created <EBox::TrafficShaping::QueueDiscipline::SFQ> object
sub new
  {

    my $class = shift;
    my %args = @_;
    my $self = {};

    # If they're null, the kernel default values are used
    $self->{pertub} = $args{pertub};
    $self->{quantum} = $args{quantum};
    # However, the advised value for pertub is 10
    $self->{pertub} = 10 unless defined( $args{pertub} );

    bless($self, $class);

    return $self;

  }

# Method: dumpTcAttr
#
#         Dump the options needed to pass the tc command
#
# Return:
#
#         String - options for the particular queue discipline
#
sub dumpTcAttr
  {
    my ($self) = @_;

    my $attrs = "sfq ";
    $attrs .= "perturb " . $self->{pertub} . " "
      if defined( $self->{pertub} );
    $attrs .= "quantum " . $self->{quantum} . "kb "
      if defined( $self->{quantum} );

    return $attrs;

  }


1;
