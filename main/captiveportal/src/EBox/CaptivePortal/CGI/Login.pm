# Copyright (C) 2011-2013 Zentyal S.L.
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
use Apache2::RequestUtil;

use constant DEFAULT_DESTINATION => '/Dashboard/Index';

sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => '',
                                  'template' => '/captiveportal/login.mas',
                                   @_);
    bless($self, $class);
    return $self;
}

sub _print
{
    my $self = shift;
    print($self->cgi()->header(-charset=>'utf-8'));
    $self->_body;
}

sub _process
{
    my $self = shift;
    my $r = Apache2::RequestUtil->request;
    my $envre;
    my $authreason;

    if ($r->prev){
        $envre = $r->prev->subprocess_env("LoginReason");
        $authreason = $r->prev->subprocess_env('AuthCookieReason');
    }

    my $destination = _requestDestination($r);

    my $reason;
    if ( (defined ($envre) ) and ($envre eq 'Script active') ) {
        $reason = __('There is a script which has asked to run in Zentyal exclusively. ' .
                     'Please, wait patiently until it is done');
    }
    elsif ((defined $authreason) and ($authreason  eq 'bad_credentials')){
        $reason = __('Incorrect password');
    }
    elsif ((defined $envre) and ($envre eq 'Expired')){
        $reason = __('For security reasons your session ' .
                 'has expired due to inactivity');
    }elsif ((defined $envre and $envre eq 'Already')){
        $reason = __('You have been logged out because ' .
                 'a new session has been opened');
    }elsif ((defined $envre and $envre eq 'NotLoggedIn')){
        $reason = __('You are not logged in');
    }

    my @htmlParams = (
              'destination' => $destination,
              'reason'      => $reason,
             );

    $self->{params} = \@htmlParams;
}

sub _requestDestination
{
    my ($r) = @_;

    if ($r->prev) {
        return _requestDestination($r->prev);
    }

    my $request = $r->the_request;
    my $method  = $r->method;
    my $protocol = $r->protocol;

    my ($destination) = ($request =~ m/$method\s*(.*?)\s*$protocol/  );
    defined $destination or return DEFAULT_DESTINATION;

    if ($destination =~ m{^/*zentyal/+Login$}) {
        # /Login is the standard location from login, his destination must be the default destination
        return DEFAULT_DESTINATION;
    }
    elsif (not $destination =~ m{^/*zentyal}) {
        # url wich does not follow the normal zentyal pattern must use the default
        #  destination
        my $dstUrl = $destination;
        $dstUrl =~ s{^.*redirect=}{};
        $dstUrl =~ s{%3f}{?};
        if ($protocol =~ m/HTTPS/i) {
            $dstUrl = 'https://' . $dstUrl;
        } else {
            $dstUrl = 'http://' . $dstUrl;
        }

        return DEFAULT_DESTINATION . "?dst=$dstUrl";
    }

    return $destination;
}

sub _validateReferer
{
    my ($self) = @_;

    # Disable referer for GET method (safe because takes no action)
    return if ($self->{cgi}->request_method() eq 'GET');

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
