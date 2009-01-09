# Copyright (C) 2008 eBox Technologies S.L.
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

package EBox::Monitor::Configuration;

# Class: EBox::Monitor::Configuration
#
#   This class is a configuration variable holder shared between
#   several objects in monitor module
#

use strict;
use warnings;

# eBox uses
use EBox::Config;

# Constants
use constant MAIN_VAR_RUN     => EBox::Config::var() . 'run/ebox/';
use constant EVENTS_DIR       => MAIN_VAR_RUN . '/events/incoming/';
use constant EVENTS_READY_DIR => EVENTS_DIR . 'ready/';

# Group: Public class methods

# Method: MainVarRun
#
# Returns:
#
#    String - the main /var/run directory for eBox
#
sub MainVarRun
{
    return MAIN_VAR_RUN;
}

# Method: EventsDir
#
# Returns:
#
#    String - the exchange directory path to communicate events and
#    monitoring
#
sub EventsDir
{
    return EVENTS_DIR;
}

# Method: EventsReadyDir
#
# Returns:
#
#    String - the exchange directory path to inform events from
#    monitoring that a new event is ready to be dispatched
#
sub EventsReadyDir
{
    return EVENTS_READY_DIR;
}

1;
