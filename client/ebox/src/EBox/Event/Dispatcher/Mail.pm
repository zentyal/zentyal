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

package EBox::Event::Dispatcher::Mail;

# Class: EBox::Dispatcher::Mail
#
# This class is a dispatcher which sends the event to an mail admin
# using SMTP protocol
#

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
use Net::SMTP;
use Net::SMTP::TLS;

# Group: Public methods

# Constructor: new
#
#        The constructor for <EBox::Event::Dispatcher::Mail>
#
#
# Returns:
#
#        <EBox::Event::Dispatcher::Mail> - the newly created object
#
sub new
  {

      my ($class) = @_;

      my $self = $class->SUPER::new('ebox');
      bless( $self, $class );

      $self->{ready}  = 0;

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

    # Mail dispatcher is configured only if the values from the
    # configuration model are set

    $self->_confParams();

    return ($self->{subject} and $self->{to} and $self->{smtp});

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

      return 'MailDispatcherConfiguration';

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

      $self->_sendMail($event);

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

      return __('Admin mail recipient');

  }

# Method: _name
#
# Overrides:
#
#       <EBox::Event::Dispatcher::Abstract::_name>
#
sub _name
  {

      return __('Mail');

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

      $self->_confParams();

      my $sender = new Net::SMTP($self->{smtp});

      unless ( defined ($sender) ) {
          throw EBox::Exceptions::External(__x('Cannot connect to {smtp} mail server',
                                               smtp => $self->{smtp}));
      }

      $sender->quit();
      $self->{ready} = 1;

  }

# Group: Private methods

# Obtain the mail event dispatcher from the configuration model. In
# order to get the data, we need to check the model manager to do so
# It will set the parameters in the instance to communicate with the
# jabber server to send messages to the admin
sub _confParams
{

    my ($self) = @_;

    my $model = EBox::Model::ModelManager::instance()->model($self->ConfigureModel());

    my $row = $model->row();

    return unless defined ( $row );

    my $values = $row->{printableValueHash};

    $self->{subject}  = $values->{subject};
    $self->{to}       = $values->{to};
    $self->{user}     = $values->{user};
    $self->{password} = $values->{password};

    if ( $row->{valueHash}->{smtp}->selectedType() eq 'eBoxSMTP' ) {
        # Get the mail domain from wherever
        $self->{smtp} = 'localhost';
    } else {
        $self->{smtp} = $values->{smtp};
    }

}

# Send the mail with the configuration parameters which are suppossed
# to set correctly
sub _sendMail
{
    my ($self, $event) = @_;

    # First, try to do it using TLS, then if not possible try to do it
    # plain without user/password and then using user/password if
    # given
    my $mailer;
    eval {
        $mailer = new Net::SMTP::TLS(
                                     $self->{smtp},
                                     Hello => 'ebox.org',
                                    );
    };
    if ($@) {
        EBox::info('Server ' . $self->{smtp} . ' does not allow '
                   . 'TLS connections without authenticate');
        if ( $self->{user} and $self->{password} ) {
            eval {
                $mailer = new Net::SMTP::TLS(
                                             $self->{smtp},
                                             Hello => 'ebox.org',
                                             user  => $self->{user},
                                             password => $self->{password},
                                            );
            };
            if ( $@ ) {
                EBox::info('Server ' . $self->{smtp} . ' does not allow '
                           . 'TLS connections at all');
                $mailer = new Net::SMTP(
                                        Host => $self->{smtp},
                                        Hello => 'ebox.org',
                                       );
                $mailer->auth( $self->{user}, $self->{password} );
            }
        } else {
            $mailer = new Net::SMTP(
                                    Host  => $self->{smtp},
                                    Hello => 'ebox.org'
                                   );
        }
    }

    if ( not defined ( $mailer )) {
        throw EBox::Exceptions::External(__x('Cannot connect to the server {hostname} '
                                             . 'to send the event through SMTP',
                                             hostname => $self->{smtp}));
    }
    # Construct the message
    $smtp->mail('ebox@ebox.org');
    $smtp->to($self->{to});

    $smtp->data();
    $smtp->datasend('Subject: ' . $self->{subject} . '\n');
    $smtp->datasend('From: ebox@' . hostname . '\n');
    $smtp->datasend('To: ' . $self->{to} . '\n');
    $smtp->datasend('\n');
    $smtp->datasend($event->level() ' : '
                    . $event->message() . '\n');
    $smtp->dataend();

    $smtp->end();

    return 1;

}

1;
