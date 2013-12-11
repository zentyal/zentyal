# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::Dispatcher::Jabber
#
# This class is a dispatcher which sends events to a Jabber account
#

# TODO: Disconnect seamlessly from the Jabber server
# TODO: Send presence from time to time

use strict;
use warnings;

package EBox::Event::Dispatcher::Jabber;

use base 'EBox::Event::Dispatcher::Abstract';

use EBox::Gettext;
use EBox::Model::Manager;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;

use Net::XMPP;
use Sys::Hostname;

# Group: Public methods

# Constructor: new
#
#        The constructor for <EBox::Event::Dispatcher::Jabber>
#
# Returns:
#
#        <EBox::Event::Dispatcher::Jabber> - the newly created object
#
sub new
{
    my ($class) = @_;

    my $self = $class->SUPER::new('ebox');
    bless ($self, $class);

    $self->{resource} = 'Zentyal';
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

    # get parameters from the model
    $self->_jabberDispatcherParams();

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
    return 'JabberDispatcherConfiguration';
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

    defined ($event) or
        throw EBox::Exceptions::MissingArgument('event');

    unless ( $self->{ready} ) {
        $self->enable();
    }

    # send to the jabber
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
    return __('Jabber Account');
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

    $self->_jabberDispatcherParams();

    # don't reenable a connection when it's already connected
    if ( defined ($self->{connection}) ) {
        if ( $self->{connection}->Connected() ) {
            # just send a presence send and return
            $self->{connection}->PresenceSend();
        } else {
            # destroy previous connection and reconnect
            $self->{connection}->Disconnect();
            $self->_confClient();
        }
    } else {
        $self->_confClient();
    }
}

# Group: Private methods

# configure the Jabber connection
sub _confClient
{
    my ($self) = @_;

    $self->{connection} = new Net::XMPP::Client();

    # gtalk needs this to work
    my $comp = undef;
    if ($self->{server} eq 'talk.google.com') {
        $comp = 'gmail.com';
    }

    my $status = $self->{connection}->Connect(
            hostname => $self->{server},
            port     => $self->{port},
            tls      => $self->{tls},
            ssl      => $self->{ssl},
            connectiontype => 'tcpip',
            componentname => $comp,
            );

    unless ( defined ($status) ) {
        throw EBox::Exceptions::External(__x('Jabber server {serverName}' .
                  ' is down or connection is not allowed.',
                  serverName => $self->{server})
        );
    }

    if ($comp) {
        my $sid = $self->{connection}->{SESSION}->{id};
        $self->{connection}->{STREAM}->{SIDS}->{$sid}->{hostname} = $comp;
    }

    my @authResult = $self->{connection}->AuthSend(
            username => $self->{user},
            password => $self->{password},
            resource => $self->{resource},
            );

    unless ( defined ($authResult[0]) ) {
        $self->_problems('AuthSend');
    }

    unless ( $authResult[0] eq 'ok' ) {
        throw EBox::Exceptions::External(__x('Authorization failed: ' .
                  '{result} - {message}',
                  result  => $authResult[0],
                  message => $authResult[1])
        );
    }

    $self->{connection}->PresenceSend();

    $self->{ready} = 1;
}

# populate the message with the event
sub _createEventMessage # (event)
{
    my ($self, $event) = @_;

    my $msg = new Net::XMPP::Message();

    my $hostname = Sys::Hostname::hostname();

    $msg->SetMessage(
            to      => $self->{adminJID},
            type    => 'chat',
            subject => 'Zentyal event on' . $hostname,
            body    => $hostname .' ['. $event->level() .']: '. $event->message(),
            );

    return $msg;
}

sub _emptyCallback
{
    return;
}

# get configuration
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
    $self->{ssl}       = $row->valueByName('ssl') eq 'ssl' ? 1 : 0;
    $self->{tls}       = $row->valueByName('ssl') eq 'tls' ? 1 : 0;
}

# method to get the error code
sub _problems
{
    my ($self, $methodName) = @_;

    EBox::error("Error processing $methodName." . $self->{connection}->GetErrorCode());

    throw EBox::Exceptions::External('Error when communicating to the Jabber server.');
}

1;
