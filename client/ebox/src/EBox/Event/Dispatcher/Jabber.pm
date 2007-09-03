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
      $self->{resource}     = 'Home';

      # Get parameters from the model
      $self->_jabberDispatcherParams();
#      $self->{server}       = 'ebox.org';
#      $self->{port}         = 5222;
#      $self->{user}         = 'logger';
#      $self->{password}     = 'foobar';
#      $self->{adminJID} = 'admin@ebox.org';

#      $self->_confClient();

      use Data::Dumper;
      EBox::debug(Dumper($self));

      return $self;

  }

# Method: configurated
#
# Overrides:
#
#        <EBox::Event::Dispatcher::Abstract::configurated>
#
sub configurated
  {

      return 'true';

  }

# Method: ConfigurationMethod
#
# Overrides:
#
#       <EBox::Event::Dispatcher::Abstract::ConfigurationMethod>
#
sub ConfigurationMethod
  {

      return 'model';

  }

# Method: ConfigureModel
#
# Overrides:
#
#        <EBox::Event::Dispatcher::Abstract::ConfigureModel>
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

      unless ( $self->{connection}->Connected() ) {
          # FIXME: Try to register
          throw EBox::Exceptions::External(__x('Authorization failed: {result} - {message}',
                                               result  => $authResult[0],
                                               message => $authResult[1],
                                              )
                                          );
      }

      # Sending presence to the ebox admin
      $self->{connection}->PresenceSend();

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

      my $model = EBox::Model::ModelManager::instance()->model($self->ConfigureModel());

      my $row = $model->row();

      return unless defined ( $row );

      my $values = $row->{printableValueHash};

      $self->{server}   = $values->{server};
      $self->{port}     = $values->{port};
      $self->{user}     = $values->{user};
      $self->{password} = $values->{password};
      $self->{adminJID} = $values->{adminJID};

  }

1;

