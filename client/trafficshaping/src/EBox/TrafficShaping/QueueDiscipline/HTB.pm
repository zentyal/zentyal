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

package EBox::TrafficShaping::QueueDiscipline::HTB;

use strict;
use warnings;

# Its parent class is QueueDiscipline
use base 'EBox::TrafficShaping::QueueDiscipline::Abstract';

# Constructor: new
#
#       Constructor for HTB (Hierarchical Token Bucket) class. It uses
#       token and bucket with classes and filters nesting buckets
#       herarchically. *Shaping* is done in leaf classes. *Borrowing*
#       tokens is done by children classes from their parentss once
#       they've excedded *rate*. A child class will continue to attempt
#       to borrow until it reaches *ceil* when it starts to queue.
#
# Parameters :
#
#       defaultClass - String Send to this class unclassified traffic with
#                      minor identifier. Only available for qdisc root.
#                      A default traffic can go to a FIFO queue which will pass packets
#                      at full speed. This class should have a minimal bandwidth. (Optional)
#       prio  - Int with the priority value (Round Robin fashion). Lower priority will
#              will be attended first. (Mandatory except for LeafClasses)
#       rate  - Int Maximum rate this class and its children are guaranteed in
#              Kilobits per second (Mandatory except for RootQDisc)
#       ceil  - Int Maximum rate a class can send.
#              ceil >= rate
#              ceil >= sum(ceil(children)) (Optional)
#       burst - Amount of kilobytes can be burst at ceil speed (Optional)
#       cburst - Amount of kilobytes can be burst at infinite speed
#       r2p    - This allows you to set coefficient for computing DRR (Deficit
#                Round Robin) quanta. The default value of 10 is good for rates
#                from 5-500kbps and should be increased for higher rates.
#                Only available for root qdisc. (Optional)
#
# Returns :
#
#      A recently created <EBox::TrafficShaping::QueueDiscipline::HTB> object
#
sub new
  {

    my $class = shift;
    my %args = @_;
    my $self = {};

    # If they're null, the kernel default values are used
    $self->{defaultClass} = $args{defaultClass};
    $self->{prio} = $args{prio};
    $self->{rate} = $args{rate};
    # Set no guaranteed rate if there's no
    $self->{rate} = 0 unless defined ( $args{rate} );
    $self->{rate} = undef if ( not defined( $args{rate} ) and
			       defined ( $args{defaultClass} ));
    $self->{ceil} = $args{ceil};
    $self->{burst} = $args{burst};
    $self->{cburst} = $args{cburst};
    $self->{r2q} = $args{r2q};

    # Set if it's root or not guessing from default class
    $self->{root} = defined( $self->{defaultClass} );

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

    my $attrs = 'htb ';
    $attrs .= 'default ' . $self->{defaultClass} . ' '
      if defined( $self->{defaultClass} );
    if ( defined( $self->{rate} ) ) {
        if ( $self->{rate} == 0 ) {
            $attrs .= 'rate 1bps ';
        } else {
            $attrs .= 'rate ' . $self->_scaleRate($self->{rate});
        }
    }

    $attrs .= "ceil " . $self->_scaleRate($self->{ceil})
      if defined( $self->{ceil} ) and ($self->{ceil} > 0);
    $attrs .= "burst " . $self->_scaleRate($self->{burst})
      if defined( $self->{burst} );
    $attrs .= "cburst " . $self->_scaleRate($self->{cburst})
      if defined( $self->{cburst} );
    $attrs .= "r2q " . $self->{r2q} . " "
      if defined( $self->{r2q} );
    $attrs .= "prio " . $self->{prio} . " "
      if defined( $self->{prio} );

    return $attrs;

}

# Group: Private methods

# Change the measure depending on the given value
# rate parameter is in kbit/s
sub _scaleRate # (rate)
{

    my ($self, $rate) = @_;

    if ( $rate >= 2 ** 20 ) {
        return ($rate / (2 ** 20 )) . 'gbit ';
    } elsif ( $rate >= 2 ** 10 ) {
        return ($rate / (2 ** 10 )) . 'mbit ';
    } else {
        return $rate . 'kbit '
    }

}

1;
