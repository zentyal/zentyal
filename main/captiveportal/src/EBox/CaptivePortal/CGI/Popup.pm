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

package EBox::CaptivePortal::CGI::Popup;

use base 'EBox::CaptivePortal::CGI::Base';

use EBox::Gettext;
use EBox::CaptivePortal;

sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new(
        'title' => '',
        'template' => '/captiveportal/popup.mas',
        @_
    );
    bless($self, $class);
    return $self;
}

sub _print
{
    my $self = shift;

    my $interval = _readInterval();
    if (not $interval) {
        $interval = 60;
    }

    my $response = $self->response();
    $response->content_type('text/html; charset=utf-8');
    $self->{params} = [ interval => $interval ];
    $response->body($self->_body);
}

sub _readInterval
{
    my $interval;

    my $path =  EBox::CaptivePortal::PERIOD_FILE;
    open my $FH, '<', $path  or
        return undef;
    $interval = <$FH>;
    close $FH;
    return $interval;
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
