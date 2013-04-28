# Copyright (C) 2013 Zentyal S.L.
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

package EBox::Util::Event;

use strict;
use warnings;

use base 'Exporter';

use POSIX;
use EBox::Config;

our @EXPORT_OK = qw(EVENTS_FIFO);
our %EXPORT_TAGS = ( constants => [ 'EVENTS_FIFO' ] );

# Constants:
#
#      EVENTS_FIFO - String the path to the named pipe to send events to
#      dispatch
#
use constant EVENTS_FIFO => EBox::Config::tmp() . 'events-fifo';

sub createFIFO
{
    # Create the named pipe
    unless ( -p EVENTS_FIFO ) {
        unlink(EVENTS_FIFO);
        POSIX::mkfifo(EVENTS_FIFO, 0700)
            or die "Can't make a named pipe: $!";
    }
}

1;
