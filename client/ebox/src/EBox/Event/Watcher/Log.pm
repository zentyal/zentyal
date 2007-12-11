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

package EBox::Event::Watcher::Log;

# Class: EBox::Event::Watcher::Log
#
#   This class is a watcher which search for new logs in Logs module
#   within an interval.
#

use base 'EBox::Event::Watcher::Base';

use strict;
use warnings;

# eBox uses
use EBox::Event;
use EBox::Event::Watcher::Base;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Global;
use EBox::Model::ModelManager;

# Dependencies
use POSIX;

# Core modules
use Error qw(:try);
use Time::Local;

# Constants
use constant LAST_QUERIED_KEY => 'LogWatcher/LastQueriedTime';
use constant PAGESIZE => 100;

# Group: Public methods

# Constructor: new
#
#        The constructor for <EBox::Event::Watcher::Log>
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
#        <EBox::Event::Watcher::Log> - the newly created object
#
sub new
{

    my ($class) = @_;

    my $self = $class->SUPER::new(
                                  period      => 10,
                                  domain      => 'ebox-logs',
                                 );
    bless( $self, $class);

    # Get the last interval queried from Events namespace
    $self->{lastQueried} = 0;
    $self->{logs} = EBox::Global->modInstance('logs');

    return $self;

}

# Method: ConfigurationMethod
#
# Overrides:
#
#       <EBox::Event::Component::ConfigurationMethod>
#
sub ConfigurationMethod
{
    return 'model';
}

# Method: ConfigureModel
#
# Overrides:
#
#       <EBox::Event::Component::ConfigureModel>
#
sub ConfigureModel
{
    return 'LogWatcherConfiguration';
}

# Method: run
#
#        Check if any logger has logged anything to create events
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::run>
#
# Returns:
#
#        undef - if no new event has been created
#
#        array ref - <EBox::Event> the events, one created per new log
#        line on every logger
#
sub run
{

    my ($self) = @_;

    my $logs = $self->{logs};
    my @loggers = keys %{$logs->getAllTables()};
    my $events = [];

    my $lastQueried = $self->_lastQueriedTime();
    my $now = time();

    my $from = $self->_toYMDHMS($lastQueried);
    my $to   = $self->_toYMDHMS($now);
    foreach my $logger (@loggers) {
        next unless $self->_isLoggerEnabled($logger);
        my $pagesize = PAGESIZE;
        my $timeCol = $logs->getTableInfo($logger)->{timecol};
        foreach my $filter (@{$self->_filters($logger)}) {
            my $finished = 0;
            my $page = 0;
            do {
                my $result = $logs->search($from, $to, $logger, $pagesize,
                                           $page, $timeCol, $filter);
                my $nPages = POSIX::ceil ( $result->{totalret} / $pagesize );
                $finished = ($page + 1) >= $nPages;
                $page++;
                my $newEvents = $self->_createEvents($logger, $result->{arrayret});
                push (@{$events}, @{$newEvents})
            } while (not $finished);
        }
    }
    $self->_setLastQueriedTime($now);

    if ( @{$events} > 0 ) {
        return $events;
    } else {
        return;
    }

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

      return __('Log observer');

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

      my $logs = $self->{logs};
      my @loggers = keys %{$logs->getAllTables()};

      my $loggersMsg = join( ', ',
                          map { $logs->getTableInfo($_)->{name} } @loggers);

      return __x('Notify when a logger ({loggers}) has logged something',
                 loggers => $loggersMsg);

  }

# Group: Private methods

# Create the <EBox::Event> objects to send to the dispatcher
sub _createEvents
{
    my ($self, $loggerName, $rows) = @_;

    my @retEvents = ();
    foreach my $row (@{$rows}) {
        my $logger = EBox::Global->modInstance($loggerName);
        push(@retEvents, new EBox::Event(
                                         message => $logger->humanEventMessage($row),
                                         level   => 'info'
                                        )
            );
    }
    return \@retEvents;
}

# Get the last queried time
sub _lastQueriedTime
{
    my ($self) = @_;

    if ( $self->{lastQueried} == 0 ) {
        # Get the last queried from State
        my $eventsMod = EBox::Global->modInstance('events');
        my $lastQueried = $eventsMod->st_get_int(LAST_QUERIED_KEY);
        if ( not defined($lastQueried) or $lastQueried == 0) {
            # First query time in ages (1 January 2000)
            $self->{lastQueried} = timelocal(0, 0, 0, 1, 1, 2000);
        } else {
            $self->{lastQueried} = $lastQueried;
        }
    }
    return $self->{lastQueried};

}

# Get the last queried time
sub _setLastQueriedTime
{
    my ($self, $lastQueried) = @_;

    $self->{lastQueried} = $lastQueried;
    my $eventsMod = EBox::Global->modInstance('events');
    $eventsMod->st_set_int(LAST_QUERIED_KEY, $lastQueried);

}

# Transform from Epoch seconds to YMDHMS date string
sub _toYMDHMS
{
    my ($self, $epochSecs) = @_;

    my ($secs, $mins, $hours, $days, $month, $year) = localtime($epochSecs);
    return sprintf( "%04d-%02d-%02d %02d:%02d:%02d",
                    $year+1900, $month, $days, $hours, $mins, $secs);
}

# Get from configuration model if an event notification from a logger
# is enabled or not
sub _isLoggerEnabled
{
    my ($self, $logger) = @_;

    my $confModel = EBox::Model::ModelManager->instance()->model($self->ConfigureModel());

    my $row = $confModel->find(domain => $logger);

    return $row->{enabled};

}

# Returns the filters used to do the search in and-ed mode
sub _filters
{

    my ($self, $logger) = @_;

    my $manager = EBox::Model::ModelManager->instance();
    my $logConfModel = $manager->model($self->ConfigureModel());
    my $loggerConfRow = $logConfModel->findValue(domain => $logger);

    my $filterDirectory = $loggerConfRow->{filters}->{directory};

    my $filterModel = $manager->model($loggerConfRow->{filters}->{model});
    $filterModel->setDirectory($filterDirectory);

    my @filterSearchs = ();
    foreach my $filterRow (@{$filterModel->rows()}) {
        my $filterSearch = {};
        foreach my $filterField (@{$filterRow->{values}}) {
            if ( $filterField->value() ) {
                $filterSearch->{$filterField->fieldName()} = $filterField->value();
            }
        }
        push ( @filterSearchs, $filterSearch );
    }

    return \@filterSearchs;

}

1;
