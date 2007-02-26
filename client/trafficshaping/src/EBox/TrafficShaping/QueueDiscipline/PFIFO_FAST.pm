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

package EBox::TrafficShaping::QueueDiscipline::PFIFO_FAST;

use strict;
use warnings;

# Its parent class is QueueDiscipline
use base 'EBox::TrafficShaping::QueueDiscipline::Abstract';

# Constructor: new
#
#       Constructor for PFIFO_FAST (Packet First In First Out) class. This
#       queue discipline has 3 bands with priorities. Band 0 is for interactive
#       traffic (+ priority) and band 3 for bulk traffic (- priority). All
#       bands acts as packet-limited FIFO queue. This is the default discipline 
#       used by Linux Kernel.
#
# Parameters :
#
#       priomap - A hash which maps via TOS every packet to a band (Optional)
#       txQueueLen - Queue length (Optional)
#
# Returns:
#
#      A recently created <EBox::TrafficShaping::QueueDiscipline::PFIFO_FAST> object
sub new
  {

    my $class = shift;
    my %args = @_;
    my $self = {};

    bless($self, $class);

    # If they're null, the kernel default values are used
    $self->{priomap} = $args{priomap};
    $self->{txQueueLen} = $args{txQueueLen};

    return $self;

  }

1;
