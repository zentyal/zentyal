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

package EBox::Event::Watcher::Monitor;

# Class: EBox::Event::Watcher::Monitor
#
#   This class is a watcher which search for new notifications from
#   the monitoring system.
#

use base 'EBox::Event::Watcher::Base';

use strict;
use warnings;

# eBox uses
use EBox::Config;
use EBox::Event;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Global;

# Core modules
use File::Tail;
use Error qw(:try);

# Constants
use constant EVENTS_DIR       => EBox::Config::var() . 'run/ebox/events/incoming/';
use constant EVENTS_READY_DIR => EVENTS_DIR . 'ready/';

# Group: Public methods

# Constructor: new
#
#        The constructor for <EBox::Event::Watcher::Monitor>
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::new>
#
# Parameters:
#
#        - non parameters
#
# Returns:
#
#        <EBox::Event::Watcher::Monitor> - the newly created object
#
sub new
{

    my ($class) = @_;

    my $self = $class->SUPER::new(
                                  period      => 10,
                                  domain      => 'ebox-monitor',
                                 );
    bless( $self, $class);

    return $self;

}

# Method: run
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::run>
#
# Returns:
#
#        undef - if no new event has been created
#
#
sub run
{
    my ($self) = @_;

    return $self->_readEventsFromDir();

}

# Group: Static class methods

# Method: ConfigurationMethod
#
# Overrides:
#
#       <EBox::Event::Component::ConfigurationMethod>
#
sub ConfigurationMethod
{
    return 'link';
}

# Method: ConfigureURL
#
# Overrides:
#
#       <EBox::Event::Component::ConfigureURL>
#
sub ConfigureURL
{
    return '/ebox/Monitor/View/MeasureWatchers';
}

# Method: Able
#
# Overrides:
#
#       <EBox::Event::Watcher::Able>
#
sub Able
{
    my $monitor = EBox::Global->modInstance('monitor');
    return $monitor->isEnabled();
}

# Group: Protected methods

# Method: _name
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::_name>
#
# Returns:
#
#        String - the event watcher name
#
sub _name
{
    return __('Monitor');
}

# Method: _description
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::_description>
#
# Returns:
#
#        String - the event watcher detailed description
#
sub _description
{
    my ($self) = @_;

    return __x('Notify when a certain value has reached a '
               . 'certain threshold');
}

# Group: Private methods

# Method: _readEventsFromDir
#
#       Read events from watchers from the exchange directory
#       EVENTS_READY_DIR
#
#       After reading the event, the file is deleted.
#
# Returns:
#
#       array ref - containing the read events if any
#
sub _readEventsFromDir
{
    my ($self) = @_;

    my $events = [];

    opendir(my $dir, EVENTS_READY_DIR)
      or return undef;

    my $filename;
    while(defined($filename = readdir($dir))) {
        my $fullName = EVENTS_READY_DIR . $filename;
        next unless (-l $fullName);
        my $hashRef;
        {
            no strict 'vars';
            $hashRef = eval File::Slurp::read_file($fullName);
        }
        my $event = $self->_parseEvent($hashRef);
        if ( UNIVERSAL::isa($event, 'EBox::Event')) {
            push(@{$events}, $event);
            unlink($fullName);
            unlink(EVENTS_DIR . $filename);
        } else {
            EBox::warn("File $fullName does not contain an hash reference");
        }
    }

    return $events;
}

# Method: _parseEvent
#
#    Parse the given hash ref and turn into an <EBox::Event> object
#
# Parameters:
#
#    hashRef - hash ref
#
# Returns:
#
#    <EBox::Event> - the blessed hash ref
#
#    undef - if the hash ref cannot be blessed
#
sub _parseEvent
{
    my ($self, $hashRef) = @_;

    my $event = undef;
    try {
        $event = new EBox::Event(%{$hashRef});
    } otherwise {
        my ($exc) = @_;
        EBox::error("Cannot parse a hash ref to EBox::Event: $!");
    };
    return $event;
}

1;
