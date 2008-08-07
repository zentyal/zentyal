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

package EBox::Event::Dispatcher::Abstract;

# Class: EBox::Event::Dispatcher::Abstract
#
# This class is the base for developing all event dispatchers by any
# module. It should inherit in order to have support for dispatching
# events within eBox framework. Every subclass should just dispatch an
# event from fixed transport way
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
#       The constructor for the <EBox::Event::Dispatcher::Abstract> object
#
# Parameters:
#
#       domain - String the Gettext domain for this event watcher
#
#       - Positional parameters
#
# Returns:
#
#       <EBox::Event::Watcher::Abstract> - the newly created object
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument> - thrown if any argument
#       is missing
#
sub new
{

      my ($class, $domain) = @_;

      defined ( $domain ) or
        throw EBox::Exceptions::MissingArgument('domain');

      my $self = $class->SUPER::new( domain => $domain );
      bless ( $self, $class);

      return $self;

}

# Method: receiver
#
#       Accessor to the receiver of what this event dispatcher
#       does. If <EBox::Event::Dispatcher::Abstract::_description> is not
#       overridden, an empty string is returned.
#
# Returns:
#
#       String - the detailed description
#
sub receiver
  {

      my ($self) = @_;

      # Get the event dispatcher Gettext domain
      my $oldDomain   = EBox::Gettext::settextdomain($self->domain());
      my $receiver = $self->_receiver();
      EBox::Gettext::settextdomain($oldDomain);

      return $receiver;

  }

# Method: configured
#
#       Indicate if the dispatcher transport layer is already
#       configured or not to send the events *(Abstract)*
#
# Returns:
#
#       boolean - whether the dispatcher is already configured or
#       not
#
sub configured
  {

      throw EBox::Exceptions::NotImplemented();

  }

# Method: enable
#
#       Set the dispatcher to work through a given configuration. This
#       method makes sure that is already configured and it will
#       test that it is enable to send the information to the
#       receiver.
#
#       An example could be the control center dispatcher that it will
#       be test its connectivity to the listening server.
#
# Returns:
#
#       true - indicating the dispatcher is enabled to send
#       events
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the dispatcher is not
#       able to send events
#
sub enable
  {

      my ($self) = @_;

      if ( $self->configured() ) {
          $self->_enable();
      } else {
          throw EBox::Exceptions::External(__x('Dispatcher {name} is not ' .
                                               'configured to be enabled',
                                              name => $self->name()));
      }

  }

# Method: send
#
#       Send an event through its own transport layer. It must be
#       overriden. *(Abstract)*
#
# Parameters:
#
#       event - <EBox::Event> the event to dispatch
#
# Returns:
#
#       boolean - whetheer the event has  been sent or not
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#       argument is missing
#
sub send
  {

      throw EBox::Exceptions::NotImplemented();

  }

# Method: configurationSubModel
#
#   Fetch the configuration submodel for a given
#   event dispacher.
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
    my $watchers = $manager->model('/events/ConfigureDispatcherDataTable');
    my $row = $watchers->findValue('eventDispatcher' => $package);
    return $row->subModel('configuration_model');
}
# Group: Protected method

# Method: _description
#
#      The i18ned method to describe the event receiver. To be
#      overridden by subclasses.
#
# Returns:
#
#      String - the receiver description. Default value: an empty
#      string.
#
sub _receiver
  {

      # Default empty implementation
      return '';

  }


# Method: _enable
#
#       It will test that it is enable to send the information to the
#       receiver. It assumes that some configuration is already
#       given. *(Abstract)*
#
#       An example could be the control center dispatcher that it will
#       be test its connectivity to the listening server.
#
# Returns:
#
#       true - if the dispatcher is enabled to send events
#
# Exceptions:
#
#       <EBox::Exceptions::External> - thrown if the dispatcher is not
#       able to send events
#
sub _enable
  {

      return 1;

  }

1;
