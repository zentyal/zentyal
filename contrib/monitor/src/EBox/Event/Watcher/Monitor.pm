# Copyright (C) 2008-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::Event::Watcher::Monitor;

use base 'EBox::Event::Watcher::Base';

# Class: EBox::Event::Watcher::Monitor
#
#   This class is a watcher which search for new notifications from
#   the monitoring system.
#

use EBox::Config;
use EBox::Event;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Global;
use EBox::Monitor::Configuration;

# Core modules
use File::Slurp;
use TryCatch::Lite;
use Time::Piece;
use Time::Seconds;

# Constants
use constant PROCESS_PLUGIN_RE => qr/cpu|load/;

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

    my $self = $class->SUPER::new(period => 10);
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
    return '/Monitor/View/MeasureWatchers';
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
        if ( UNIVERSAL::isa($event, 'EBox::Event') ) {
            if ( $event->message()) {
                push(@{$events}, $event);
            } else {
                EBox::debug('Notificated with the following message: '
                            . File::Slurp::read_file($fullName));
            }
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
        ($hashRef->{message}, $hashRef->{additional}) = $self->_i18n(
            $hashRef->{level}, $hashRef->{message},
            $hashRef->{duration}, $hashRef->{other},
           );
        $event = new EBox::Event(%{$hashRef});
    } catch ($e) {
        EBox::error("Cannot parse a hash ref to EBox::Event: $! $e");
    }
    return $event;
}

# From collectd strings
#: Data source "%s" is currently %f. That is within the %s region of %f and %f.
#: Data source "%s" is currently %f. That is %s the %s threshold of %f.

# Internalization of the message
sub _i18n
{
    my ($self, $severity, $message, $duration, $other) = @_;

    my ($measureName, $typeName, undef) = $message =~ m/plugin (.*?) .*type (.*?)(| .*): /g;
    # Example: "Received a value for <host>/<measure>/<typeInstance>. It was missing for 24 seconds."
    return '' unless (defined($measureName));

    my ($measureInstance) = $message =~ m/plugin.*?\(instance (.*?)\) type/g;
    my ($typeInstance)    = $message =~ m/type.*?\(instance (.*?)\):/g;

    my ($dataSource, $currentValue) = $message =~ m/Data source "(.*?)" is currently (.*?)\. /g;

    my $monMod = EBox::Global->modInstance('monitor');
    my $measure = $monMod->measure($measureName);

    my $what = $measure->printableName();
    if (defined($measureInstance)) {
        $what = $measure->printableInstance($measureInstance);
    }

    my $printableMsg = '';
    my $additionalInfo = { 'measure'          => $measureName,
                           'measure_instance' => $measureInstance,
                           'type'             => $typeName,
                           'type_instance'    => $typeInstance,
                           'severity'         => $severity,
                           'data_source'      => $dataSource,
                           'value'            => $currentValue,
                       };
    if ( $severity eq 'info' ) {
        $printableMsg = __('All data sources are within range again');
    } else {
        my $printableDataSource;
        if ( defined($typeInstance) and  $dataSource eq 'value' ) {
            $printableDataSource = $measure->printableTypeInstance($typeInstance);
        } else {
            $printableDataSource = $measure->printableLabel($typeInstance, $dataSource);
        }

        $additionalInfo->{metric}      = $measure->metric();
        $additionalInfo->{duration}    = $duration;

        $printableMsg .= __x('{what} "{dS}" is currently {value}.',
                             what => $what, dS => $printableDataSource,
                             value => $measure->formattedGaugeType($currentValue));
        $printableMsg .= ' ';

        if ( $message =~ m:region of:g ) {
            my ($minBound, $maxBound) = $message =~ m:region of (.*?) and (.*)\.$:;
            $additionalInfo->{min_bound} = $minBound;
            $additionalInfo->{max_bound} = $maxBound;
            if ( defined($duration) and $duration > 0 ) {
                $printableMsg = __x('{what} "{dS}" has been {duration} within the {severity} '
                                    . 'region of {minBound} and {maxBound}.',
                                    what => $what, dS => $printableDataSource,
                                    duration => $self->_formatDuration($duration),
                                    severity => $severity, minBound => $measure->formattedGaugeType($minBound),
                                    maxBound => $measure->formattedGaugeType($maxBound) );
            } else {
                $printableMsg .= __x('That is within the {severity} region of {minBound} '
                                     . 'and {maxBound}. ',
                                     severity => $severity, minBound => $measure->formattedGaugeType($minBound),
                                     maxBound => $measure->formattedGaugeType($maxBound) );
            }
        }
        if ( $message =~ m:threshold of:g ) {
            my ($adverb, $bound) = $message =~ m:That is (.*?) the.*threshold of (.*)\.$:;
            if ( $adverb eq 'above') {
                $additionalInfo->{max_bound} = $bound;
                if ( defined($duration) and $duration > 0 ) {
                    $printableMsg = __x('{what} "{dS}" has been {duration} above the {severity} threshold of {bound}. ',
                                        what => $what, dS => $printableDataSource,
                                        duration => $self->_formatDuration($duration),
                                        severity => $severity, bound => $measure->formattedGaugeType($bound) );
                } else {
                    $printableMsg .= __x('That is above the {severity} threshold of {bound}. ',
                                         severity => $severity, bound => $measure->formattedGaugeType($bound) );
                }
            } elsif ( $adverb eq 'below') {
                $additionalInfo->{min_bound} = $bound;
                if ( defined($duration) and $duration > 0 ) {
                    $printableMsg = __x('{what} "{dS}" has been {duration} below the {severity} threshold of {bound}. ',
                                        what => $what, dS => $printableDataSource,
                                        duration => $self->_formatDuration($duration),
                                        severity => $severity, bound => $measure->formattedGaugeType($bound) );
                } else {
                    $printableMsg .= __x('That is below the {severity} threshold of {bound}. ',
                                         severity => $severity, bound => $measure->formattedGaugeType($bound) );
                }
            }
        }
    }

    if ( defined($other) and $measureName =~ PROCESS_PLUGIN_RE and @{$other} > 0 ) {
        # Print out the list of culprit processes
        my $t = new Proc::ProcessTable();
        my $realProcNum = 0;
        my $procMsgs = "";
        $additionalInfo->{processes} = [];
        foreach my $pid ( @{$other} ) {
            my ($proc) = grep { $_->pid() == $pid } @{$t->table()};
            next unless defined($proc);
            my $format = "%-6s  %-19s  %s\n";
            my $time = localtime($proc->start());
            my $timeStr = sprintf('%04s-%02s-%02s %02s:%02s:%02s', $time->year(),
                                  $time->mon(), $time->mday(),
                                  $time->hour(), $time->minute(),
                                  $time->second());
            $procMsgs .= sprintf($format,
                                 $pid,
                                 $timeStr,
                                 $proc->cmndline());
            $realProcNum++;
            push(@{$additionalInfo->{processes}},
                 { pid => $pid, time => $timeStr, proc => $proc->cmndline() });
        }
        if ( $realProcNum > 0 ) {
            $printableMsg .= "\n\n";
            $printableMsg .= __x('The following {n} processes are likely causing it:',
                                 n => $realProcNum);
            $printableMsg .= "\n$procMsgs";
        } # No message
    }

    return ($printableMsg, $additionalInfo);
}

# Format to human-readable format a duration time
sub _formatDuration
{
    my ($self, $duration) = @_;

    my $secObj = new Time::Seconds($duration);

    my ($hours, $mins);
    if ( $secObj >= Time::Seconds::ONE_MINUTE ) {
        if ( $secObj >= Time::Seconds::ONE_HOUR ) {
            $hours = int($secObj->hours());
            $secObj -= ($hours * Time::Seconds::ONE_HOUR);
        }
        $mins = int($secObj->minutes());
        $secObj -= ($mins * Time::Seconds::ONE_MINUTE);
    }
    my $secs = $secObj->seconds();

    if ( $hours ) {
        return __x('{h}h {m}m {s}s',
                   h => $hours, m => $mins, s => $secs);
    } elsif ( $mins ) {
        return __x('{m}m {s}s',
                   m => $mins, s => $secs);
    } else {
        return __x('{s}s', s => $secs);
    }
}

1;
