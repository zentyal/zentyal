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

package EBox::Event::Watcher::Base;

# Class: EBox::Event::Watcher::Base
#
# This class is the base for developing all event watchers by any
# module. It should inherit in order to have support for reporting
# events within eBox framework. Every subclass should just watch one
# event.
#

use strict;
use warnings;

use base 'EBox::Event::Component';

# eBox uses
use EBox::Exceptions::NotImplemented;
use EBox::Exceptions::MissingArgument;
use EBox::Event;
use EBox::Gettext;

# Constructor: new
#
#       The constructor for the <EBox::Event::Watcher::Base> object
#
# Parameters:
#
#       period - Integer the period in number of calls between
#       <watchEvent> calls
#       domain - String the Gettext domain for this event watcher
#
#       - Named parameters
#
# Returns:
#
#       <EBox::Event::Watcher::Base> - the newly created object
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument> - thrown if any argument
#       is missing
#
sub new
  {
      my ($class, %args) = @_;

      defined ( $args{period} ) or
        throw EBox::Exceptions::MissingArgument('period');

      my $self = $class->SUPER::new(%args);
      bless ($self, $class);

      $self->{period} = $args{period};

      return $self;
  }

# Method: period
#
#       Accessor to the period among <watchEVent> calls
#
# Returns:
#
#       Integer - the number of minutes between <watchEvent> calls
#
sub period
  {

      my ($self) = @_;

      return $self->{period};

  }


# Method: description
#
#       Accessor to the description of what this event watcher
#       does. If <EBox::Event::Watcher::Base::_description> is not
#       overridden, an empty string is returned.
#
# Returns:
#
#       String - the detailed description
#
sub description
{

    my ($self) = @_;

    # Get the event watcher Gettext domain
    my $oldDomain   = EBox::Gettext::settextdomain($self->domain());
    my $description = $self->_description();
    EBox::Gettext::settextdomain($oldDomain);

    return $description;

}


# Method: run
#
#       Check an event to report it. This method will take into
#       account anything in the system to get known if the watched
#       event has happened. It must be overriden. *(Abstract)*
#
# Returns:
#
#       undef - if no new event has been reported
#
#       array ref - containing <EBox::Event> which as many events as they have
#       happened event has happened
#
sub run
  {

      throw EBox::Exceptions::NotImplemented();

  }

# Group: Class static methods

# Method: Able
#
#      Check if the event watcher is able to watch and monitor an
#      event. If it is unable, then the event will never happen
#      anyway.
#
# Example:
#
#      Monitoring RAID events in a flat disk subsystem has no sense
#
# Returns:
#
#      boolean - indicating if the event watcher is able to monitor a
#      set of events
#
# Default value:
#
#      true
#
sub Able
{
    return 1;
}

# Method: configurationSubModel
#
#   Fetch the configuration submodel for a given
#   event watcher.
#
#   Given a class name it will look up the row
#   of the model which  contains this class, and
#   it will return its configuration model
#
# Parameters:
#
#   package - String containing a class to look up
#
# Returns:
#
#   An instance of <EBox::Model::DataTable>
#
#
sub configurationSubModel
{
    my ($self, $package) = @_;

    defined ( $package ) or
        throw EBox::Exceptions::MissingArgument('package');

    my $manager = EBox::Model::ModelManager->instance();
    my $watchers = $manager->model('/events/ConfigureEventDataTable');
    my $row = $watchers->findValue('eventWatcher' => $package);
    return $row->subModel('configuration_model');
}

# Group: Protected method

# Method: _description
#
#      The i18ned method to describe the event watcher. To be
#      overridden by subclasses.
#
# Returns:
#
#      String - the description. Default value: an empty string.
#
sub _description
  {

      # Default empty implementation
      return '';

  }



1;
