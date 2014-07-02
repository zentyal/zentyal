# Copyright (C) 2010-2014 Zentyal S.L.
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

use EBox;
use EBox::Gettext;
use EBox::CaptivePortal;
use EBox::CaptivePortal::CGI::Run;

use Plack::Builder;
use Plack::Session::Store::File;
use POSIX qw(:signal_h setlocale LC_ALL LC_NUMERIC);

use constant SESSIONS_PATH => EBox::CaptivePortal->SIDS_DIR;

my $app = sub {
    my $env = shift;

    EBox::initLogger('captiveportal-log.conf');
    POSIX::setlocale(LC_ALL, EBox::locale());
    POSIX::setlocale(LC_NUMERIC, 'C');

    # Clear process signals mask
    my $sigset = POSIX::SigSet->new();
    $sigset->fillset();
    sigprocmask(SIG_UNBLOCK, $sigset);

    binmode(STDOUT, ':utf8');

    my $req = Plack::Request->new($env);
    return EBox::CaptivePortal::CGI::Run->run($req);
};

builder {
    enable "+EBox::Middleware::UnhandledError";
    enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' }
        "ReverseProxy";
    enable "Session",
        state   => 'Plack::Session::State::Cookie',
        store   => new Plack::Session::Store::File(dir => SESSIONS_PATH);
    enable "+EBox::CaptivePortal::Middleware::AuthLDAP",
        app_name => 'captiveportal';
    $app;
};

