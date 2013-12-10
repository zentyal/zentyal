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

# Class: EBox::Dispatcher::Mail
#
# This class is a dispatcher which sends the event to a mail account
# using the local mail server.
#

use strict;
use warnings;

package EBox::Event::Dispatcher::Mail;

use base 'EBox::Event::Dispatcher::Abstract';

use EBox::Global;
use EBox::Gettext;
use EBox::Model::Manager;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;

use Error qw(:try);

use Net::SMTP;

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

    my $self = $class->SUPER::new('ebox-mail');
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
    return __('Mail Account');
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

    my $sender = $self->_getMailer();

    $sender->quit();

    $self->{ready} = 1;
}

# Group: Private methods

# get configuration
sub _confParams
{
    my ($self) = @_;

    my $model = $self->configurationSubModel(__PACKAGE__);

    my $row = $model->row();

    return unless defined ( $row );

    $self->{subject}  = $row->valueByName('subject');
    $self->{to}       = $row->valueByName('to');
    $self->{smtp}     = 'localhost';
    $self->{mailname} = EBox::Global->modInstance('mail')->mailname();
}

# send the event mail
sub _sendMail
{
    my ($self, $event) = @_;

    my $mailer = $self->_getMailer();

    $mailer->mail('zentyal-noreply@' . $self->{mailname});
    $mailer->to($self->{to});

    $mailer->data();
    $mailer->datasend('Subject: ' . $self->{subject} . "\n");
    $mailer->datasend('From: zentyal-noreply@' . $self->{mailname} . "\n");
    $mailer->datasend('To: ' . $self->{to} . "\n");
    $mailer->datasend("\n");
    $mailer->datasend($event->level() . ' : '
                    . $event->message() . "\n");
    $mailer->dataend();

    $mailer->quit();

    return 1;
}

# get the mailer
sub _getMailer
{
    my ($self) = @_;

    my $mailer = new Net::SMTP(
                                $self->{smtp},
                                Hello => $self->{mailname},
                                Timeout => 30,
                               );

    if ( not defined ( $mailer ) ) {
        throw EBox::Exceptions::External(__x('Cannot connect to {smtp} mail server.',
                                             smtp => $self->{smtp}));
    }

    return $mailer;
}

1;
