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

package EBox::Event::Dispatcher::Jabber;

# Class: EBox::Dispatcher::Jabber
#
# This class is a dispatcher which sends the event to an admin
#

# TODO: Disconnect seamlessly from the Jabber server
# TODO: Send presence from time to time

use base 'EBox::Event::Dispatcher::Abstract';

use strict;
use warnings;

# eBox uses
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Model::ModelManager;

################
# Dependencies
################
use Data::Dumper;
use Net::Jabber;
use Net::Jabber::Message;

# Group: Public methods

# Constructor: new
#
#        The constructor for <EBox::Event::Dispatcher::Jabber>
#
#
# Returns:
#
#        <EBox::Event::Dispatcher::Jabber> - the newly created object
#
sub new
  {

      my ($class) = @_;

      my $self = $class->SUPER::new('ebox');
      bless( $self, $class );

      # The required parameters
      $self->{resource} = 'Home';
      $self->{ready}  = 0;

      # Get parameters from the model
      $self->_jabberDispatcherParams();
#      $self->{server}       = 'jabber.escomposlinux.org';
#      $self->{port}         = 5222;
#      $self->{user}         = 'ebox-logger';
#      $self->{password}     = 'logger';
#      $self->{adminJID}     = 'quique_h@jabber.org';
#      $self->{subscribe}    = 1;

#      $self->_confClient();

      return $self;

  }

# Method: configured
#
# Overrides:
#
#        <EBox::Event::Dispatcher::Abstract::configured>
#
sub configured
  {

      my ($self) = @_;

      # Jabber dispatcher is configured only if the values from the
      # configuration model are set
      return ($self->{server} and $self->{port} and
        $self->{user} and $self->{password} and $self->{adminJID});

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
#        <EBox::Event::Component::ConfigureModel>
#
sub ConfigureModel
  {

      return 'JabberDispatcherForm';

  }

# Method: send
#
#        Send the event to the admin using Jabber protocol
#
# Overrides:
#
#        <EBox::Event::Dispatcher::Abstract::send>
#
sub send
  {

      my ($self, $event) = @_;

      defined ( $event ) or
        throw EBox::Exceptions::MissingArgument('event');

      unless ( $self->{ready} ) {
          $self->enable();
      }

      # Send to the jabber
      my $msg = $self->_createEventMessage($event);
      $self->{connection}->Send($msg);

      return 1;

  }

# Group: Protected methods

# Method: _receiver
#
# Overrides:
#
#       <EBox::Event::Dispatcher::Abstract::_receiver>
#
sub _receiver
  {

      return __('Admin Jabber account');

  }

# Method: _name
#
# Overrides:
#
#       <EBox::Event::Dispatcher::Abstract::_name>
#
sub _name
  {

      return __('Jabber');

  }

# Method: _enable
#
# Overrides:
#
#        <EBox::Event::Dispatcher::Abstract::_enable>
#
sub _enable
  {

      my ($self) = @_;

      # Don't reenable a connection when it's already connected
      if ( defined ( $self->{connection} )) {
          if ( $self->{connection}->Connected() ) {
              # Just send a presence send and return
              $self->{connection}->PresenceSend();
          } else {
              # Destroy previous connection and reconnect
              $self->{connection}->Disconnect();
              $self->_confClient();
          }
      } else {
          $self->_confClient();
      }

  }

# Group: Private methods

# Configurate the jabber connection
sub _confClient
  {

      my ($self) = @_;

      $self->{connection} = new Net::Jabber::Client();

      # Empty callbacks at this time

      # Server connection
      my $status = $self->{connection}->Connect(
                                                hostname => $self->{server},
                                                port     => $self->{port},
                                               );

      unless ( defined ( $status )) {
          throw EBox::Exceptions::External(__x('Jabber server {serverName}' .
                                              ' is down or connection is not allowed',
                                               serverName => $self->{server})
                                          );
      }

      # Server authentication
      my @authResult = $self->{connection}->AuthSend(
                                                     username => $self->{user},
                                                     password => $self->{password},
                                                     resource => $self->{resource},
                                                    );

      unless ( defined ( $authResult[0] )) {
          $self->_problems('AuthSend');
      }

      unless ( $authResult[0] eq 'ok' ) {
          if ( $self->{subscribe} ) {
              # Try to register the user
              my @registerResult = @{$self->_register()};

              if ( $registerResult[0] eq 'ok' ) {
                  # Registration was ok
                  $self->{subscribe} = 0;
                  $self->{connection}->Disconnect();
                  # Reconnect to authenticate
                  $self->_confClient();
                  return;
              } else {
                  throw EBox::Exceptions::External(__x('Subscription failed: {message}',
                                                       message => $registerResult[1]
                                                       )
                                                  );
              }

          } else {
              throw EBox::Exceptions::External(__x('Authorization failed: {result} - {message}',
                                                   result  => $authResult[0],
                                                   message => $authResult[1],
                                                  )
                                              );
          }
      }

      # Sending presence to the ebox admin
      $self->{connection}->PresenceSend();

      # Flag to indicate the Jabber dispatcher is ready to send messages
      $self->{ready} = 1;

  }

# Populate the message with the event
sub _createEventMessage # (event)
  {

      my ($self, $event) = @_;

      my $msg = new Net::Jabber::Message();

      $msg->SetMessage(
                       to      => $self->{adminJID},
                       type    => 'normal',
                       subject => 'eBox event',
                       body    => $event->level() . ' : ' . $event->message(),
                      );

      return $msg;

  }

sub _emptyCallback
  {

      return;

  }

# Obtain the jabber event dispatcher from the configuration model. In
# order to get the data, we need to check the model manager to do so
# It will set the parameters in the instance to communicate with the
# jabber server to send messages to the admin
sub _jabberDispatcherParams
  {

      my ($self) = @_;

      my $model = $self->configurationSubModel(__PACKAGE__); 

      my $row = $model->row();

      return unless defined ( $row );

      $self->{server}    = $row->valueByName('server');
      $self->{port}      = $row->valueByName('port');
      $self->{user}      = $row->valueByName('user');
      $self->{password}  = $row->valueByName('password');
      $self->{adminJID}  = $row->valueByName('adminJID');
      $self->{subscribe} = $row->valueByName('subscribe');

  }

# Method to try to register at the Jabber server
sub _register
  {

      my ($self) = @_;

      my %requestResult = $self->{connection}->RegisterRequest();

      unless (scalar ( keys ( %requestResult )) >= 0) {
          $self->_problems('RegisterRequest');
      }

      my @registerResult = $self->{connection}->RegisterSend(
                                     username => $self->{user},
                                     password => $self->{password},
                                     name     => 'eBox de Platform',
                                     email => 'ebox@eboxplatform.com',
                                                            );

      unless ( defined ( $registerResult[0] )) {
          $self->_problems('AuthSend');
      }

      return \@registerResult;

  }

# Method to get the error code
sub _problems
  {

      my ($self, $methodName) = @_;

      EBox::error("Error processing $methodName " .
                  $self->{connection}->GetErrorCode());

      throw EBox::Exceptions::Internal('Error when communicating to the Jabber server');
  }

1;
