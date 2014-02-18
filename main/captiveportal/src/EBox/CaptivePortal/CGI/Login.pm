# Copyright (C) 2011-2014 Zentyal S.L.
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

package EBox::CaptivePortal::CGI::Login;
use base 'EBox::CaptivePortal::CGI::Base';

use EBox::Gettext;

use constant DEFAULT_DESTINATION => '/Dashboard/Index';

sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new(
        'title' => '',
        'template' => '/captiveportal/login.mas',
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

    my $destination = $self->_requestDestination($session);

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

    my @htmlParams = (
        'destination' => $destination,
        'reason'      => $reason,
    );

    $self->{params} = \@htmlParams;
}

sub _requestDestination
{
    my ($self, $session) = @_;

    unless (defined $session->{redir_to}) {
        return DEFAULT_DESTINATION;
    }

    if ($session->{redir_to} =~ m{^/*zentyal/+Login$}) {
        # /Login is the standard location from login, his destination must be the default destination
        return DEFAULT_DESTINATION;
    } elsif (not $session->{redir_to} =~ m{^/*zentyal}) {
        # url wich does not follow the normal zentyal pattern must use the default
        #  destination
        my $dstUrl = $session->{redir_to};
        $dstUrl =~ s{^.*redirect=}{};
        $dstUrl =~ s{%3f}{?};
        my $request = $self->request();
        if ($request->scheme() =~ m/HTTPS/i) {
            $dstUrl = 'https://' . $dstUrl;
        } else {
            $dstUrl = 'http://' . $dstUrl;
        }

        return DEFAULT_DESTINATION . "?dst=$dstUrl";
    }

    return $session->{redir_to};
}

# Method: _validateReferer
#
#   Checks whether the referer header has valid information.
#
# Overrides: <EBox::CaptivePortal::CGI::Base::_validateReferer>
#
# FIXME: EBox::CaptivePortal::CGI::Base disables all kind of validation, does it makes sense?
sub _validateReferer
{
    my ($self) = @_;

    # Disable referer for GET method (safe because takes no action)
    my $request = $self->request();
    return if ($request->method() eq 'GET');

    $self->SUPER::_validateReferer(@_);
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
