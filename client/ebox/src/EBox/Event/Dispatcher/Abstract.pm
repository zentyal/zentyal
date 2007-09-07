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

      my $self = { domain => $domain };

      bless ( $self, $class);

      return $self;

  }

# Method: domain
#
#       Accessor to the Gettext domain
#
# Returns:
#
#       String - the Gettext domain
#
sub domain
  {

      my ($self) = @_;

      return $self->{domain};

  }

# Method: description
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

# Method: name
#
#       Accessor to the event dispatcher identifier. If
#       <EBox::Event::Dispatcher::Abstract::_name> is not overridden, the
#       class name is returned.
#
# Returns:
#
#       String - the unique name
#
sub name
  {

      my ( $self ) = @_;

      my $oldDomain = EBox::Gettext::settextdomain($self->domain());
      my $dispatcherName = $self->_name();
      EBox::Gettext::settextdomain($oldDomain);

      return $dispatcherName;

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


# Method: ConfigurationMethod
#
#       Class method which determines which kind of method is used in
#       order to select which kind of configuration will be used. This
#       method should be overridden.
#
# Returns:
#
#       String - one of the following:
#           - link - if the configuration is done via URL
#           - model - if the configuration is done via Model
#           - none - if no configuration is required
#
sub ConfigurationMethod
  {

      throw EBox::Exceptions::NotImplemented();

  }

# Method: ConfigureURL
#
#       Get the configuration URL to set the configuration. Static
#       method.
#
# Returns:
#
#       String - the URL where to set the configuration
#
sub ConfigureURL
  {

      throw EBox::Exceptions::NotImplemented();

  }

# Method: ConfigureModel
#
#       Get the configuration model to set the dispatcher
#       configuration. Static method.
#
# Returns:
#
#       String - the model which describe the configuration
#
sub ConfigureModel
  {

      throw EBox::Exceptions::NotImplemented();

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

# Method: _name
#
#      The i18ned method to name the event dispatcher. To be
#      overridden by subclasses.
#
# Returns:
#
#      String - the name. Default value: the class name
#
sub _name
  {

      my ($self) = @_;

      # Default, return the class name
      return ref ( $self );

  }

1;
