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
use EBox::Gettext;

# Constants
use constant MAIN_VAR_RUN     => EBox::Config::var() . 'run/ebox/';
use constant EVENTS_DIR       => MAIN_VAR_RUN . '/events/incoming/';
use constant EVENTS_READY_DIR => EVENTS_DIR . 'ready/';
use constant QUERY_INTERVAL      => 10;

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

# Method: QueryInterval
#
#      Return the collectd query interval to plugins
#
# Return:
#
#      Int - the query interval
#
sub QueryInterval
{
    return QUERY_INTERVAL;
}

# Method: TimePeriods
#
#      Return the configured time periods for Monitoring
#
# Return:
#
#      array ref - the time periods with the following values:
#
#        name          - String the period's name
#        printableName - String the printable name
#        resolution    - Int the resolution in seconds
#        timeValue     - String to send to 'rrdtool fetch' app. ie '1d'
#
sub TimePeriods
{
    return [ { name => 'lastHour',
               printableName => __('Last hour'),
               resolution    => 10,
               timeValue     => '1h'
              },
             { name => 'lastDay',
               printableName => __('Last day'),
               resolution    => (15 * 60),
               timeValue     => '1d'
              },
             { name => 'lastMonth',
               printableName => __('Last month'),
               resolution    => 21600,
               timeValue     => '1month'
              },
             { name => 'lastYear',
               printableName => __('Last year'),
               resolution    => (60*60*24),
               timeValue     => '1y'
              }
            ];
}

1;
