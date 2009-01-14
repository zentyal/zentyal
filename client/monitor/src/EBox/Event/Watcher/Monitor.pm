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
use EBox::Monitor::Configuration;

# Core modules
use File::Slurp;
use Error qw(:try);

# Constants

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
#       EBox::Monitor::Configuration::EventsReadyDir()
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

    opendir(my $dir, EBox::Monitor::Configuration::EventsReadyDir())
      or return undef;

    my $filename;
    while(defined($filename = readdir($dir))) {
        my $fullName = EBox::Monitor::Configuration::EventsReadyDir() . $filename;
        next unless (-l $fullName);
        my $hashRef;
        {
            no strict 'vars';
            $hashRef = eval File::Slurp::read_file($fullName);
        }
        my $event = $self->_parseEvent($hashRef);
        if ( UNIVERSAL::isa($event, 'EBox::Event')) {
            push(@{$events}, $event);
        } else {
            EBox::warn("File $fullName does not contain an hash reference");
##            EBox::warn("Its content is: " . File::Slurp::read_file($fullName));
        }
        unlink($fullName);
        unlink(EBox::Monitor::Configuration::EventsDir() . $filename);
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
        if ( $self->_filterDataSource($hashRef->{message}) ) {
            $hashRef->{message} = $self->_i18n($hashRef->{level}, $hashRef->{message});
            $event = new EBox::Event(%{$hashRef});
        }
    } otherwise {
        my ($exc) = @_;
        EBox::error("Cannot parse a hash ref to EBox::Event: $! $exc");
    };
    return $event;
}

# Method: _filterDataSource
#
#     Filter Data Source (Collectd from 4.4 onwards, do itself) so
#     that an event notification is done only on those data source
#     from a threshold configuration row indicated by the user. This
#     is mandatory, for instance, for getting notification when free
#     disk space is lower than a certain threshold for a partition.
#
# Returns:
#
#     true - if the message contains a data source and there is a row
#     in threshold configuration or there is no data source applicable
#
#     false - if the message contains a data source and there is no
#     row in threshold configuration
#
sub _filterDataSource
{
    my ($self, $message) = @_;

    my ($plugin, $dataSource) = $message =~ m:.*plugin (.*?) .*Data source "(.*?)":ig;

    # Default data source is called value (not applicable in Web UI)
    return 1 if ($dataSource eq 'value');

    my $monMod = EBox::Global->modInstance('monitor');
    return $monMod->thresholdConfigured($plugin, $dataSource);

}

# From collectd strings
#: Data source "%s" is currently %f. That is within the %s region of %f and %f.
#: Data source "%s" is currently %f. That is %s the %s threshold of %f.

# Internalization of the message
sub _i18n
{
    my ($self, $severity, $message) = @_;

    my ($measureName, $typeName, $waste,$dataSource, $currentValue) =
      $message =~ m/plugin (.*?) .*type (.*?)(| .*): Data source "(.*?)" is currently (.*?)\. /g;

    my ($measureInstance) = $message =~ m/plugin.*?\(instance (.*?)\) type/g;
    my ($typeInstance)    = $message =~ m/type.*?\(instance (.*?)\):/g;

    my $monMod = EBox::Global->modInstance('monitor');
    my $measure = $monMod->measure($measureName);

    my $what = $measure->printableName();
    if (defined($measureInstance)) {
        $what = $measure->printableInstance($measureInstance);
    }

    my $printableDataSource = $measure->printableDataSource($dataSource);
    if ( defined($typeInstance) ) {
        if ( $dataSource eq 'value' ) {
            $printableDataSource = $measure->printableTypeInstance($typeInstance);
        } else {
            $printableDataSource = $measure->printableTypeInstance($typeInstance) . " $printableDataSource";
        }
    }

    my $printableMsg = __x('{what} "{dS}" is currently {value}.', what => $what, dS => $printableDataSource,
                           value => $currentValue);
    $printableMsg .= ' ';

    if ( $message =~ m:region of:g ) {
        my ($minBound, $maxBound) = $message =~ m:region of (.*?) and (.*)\.$:;
        $printableMsg .= __x('That is within the {severity} region of {minBound} and {maxBound}.',
                             severity => $severity, minBound => $minBound,
                             maxBound => $maxBound);
    }
    if ( $message =~ m:threshold of:g ) {
        my ($adverb, $bound) = $message =~ m:That is (.*?) the.*threshold of (.*)\.$:;
        if ( $adverb eq 'above') {
            $printableMsg .= __x('That is above the {severity} threshold of {bound}.',
                                 severity => $severity, bound => $bound);
        } elsif ( $adverb eq 'below') {
            $printableMsg .= __x('That is below the {severity} threshold of {bound}.',
                                 severity => $severity, bound => $bound);
        }
    }

    return $printableMsg;

}

1;
