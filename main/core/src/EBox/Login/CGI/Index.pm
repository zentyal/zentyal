# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::Login::CGI::Index;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;

use Readonly;
Readonly::Scalar my $DEFAULT_DESTINATION => '/Dashboard/Index';
Readonly::Scalar my $FIRSTTIME_DESTINATION => '/Software/Welcome';
Readonly::Scalar my $ACTIVATION_DESTINATION => '/ActivationRequired';

sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new(
        'title'    => '',
        'template' => '/login/index.mas',
        @_);
    bless($self, $class);
    return $self;
}

sub _print
{
    my ($self) = @_;

    my $response = $self->response();
    $response->content_type('text/html; charset=utf-8');
    $response->body($self->_body);
}

sub _process
{
    my ($self) = @_;

    my $authreason;
    my $request = $self->request();
    my $session = $request->session();
    if (exists $session->{AuthReason}){
        $authreason = delete $session->{AuthReason};
    }

    my $destination = _requestDestination($session);

    my $reason;
    if (defined $authreason) {
        if ($authreason eq 'Script active') {
            $reason = __('There is a script which has asked to run in Zentyal exclusively. ' .
                         'Please, wait patiently until it is done');
        } elsif ($authreason eq 'Invalid session'){
            $reason = __('Your session was not valid anymore');
        } elsif ($authreason  eq 'Incorrect password'){
            $reason = __('Incorrect password');
        } elsif ($authreason eq 'Expired'){
            $reason = __('For security reasons your session has expired due to inactivity');
        } elsif ($authreason eq 'Already'){
            $reason = __('You have been logged out because a new session has been opened');
        } else {
            $reason = __x("Unknown error: '{error}'", error => $authreason);
        }
    }

    my $global = EBox::Global->getInstance();

    my @htmlParams = (
        'destination'       => $destination,
        'reason'            => $reason,
        %{ $global->theme() }
    );

    $self->{params} = \@htmlParams;
}

sub _requestDestination
{
    my ($session) = @_;

    my $edition = EBox::Global::edition();
    if (($edition eq 'trial-expired') or ($edition eq 'require-activation')) {
        return $ACTIVATION_DESTINATION;
    }

    # redirect to software selection on first install
    if (EBox::Global::first() and EBox::Global->modExists('software')) {
        return $FIRSTTIME_DESTINATION;
    }

    unless (defined $session->{redir_to}) {
        return $DEFAULT_DESTINATION;
    }

    if ($session->{redir_to} =~ m{^/*Login/+Index$}) {
        # /Login/Index is the standard location from login, his destination must be the default destination
        return $DEFAULT_DESTINATION;
    }

    return $session->{redir_to};
}

sub _top
{
}

sub _loggedIn
{
    return 1;
}

sub _menu
{
    return;
}

1;
