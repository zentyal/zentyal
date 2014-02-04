#!/usr/bin/perl
# Copyright (C) 2010-2013 Zentyal S.L.
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
use EBox::CGI::Run;
use EBox::Gettext;

use Authen::Simple::PAM;
use Plack::Builder;
use Plack::Session::Store::File;
use POSIX qw(:signal_h);

use constant SESSIONS_PATH => '/var/lib/zentyal/tmp';

my $app = sub {
    my $env = shift;

    # Clear process signals mask
    my $sigset = POSIX::SigSet->new();
    $sigset->fillset();
    sigprocmask(SIG_UNBLOCK, $sigset);

    EBox::init();
    binmode(STDOUT, ':utf8');

    use Data::Dumper;
    EBox::debug(Dumper($env));

    my $req = Plack::Request->new($env);
    return EBox::CGI::Run->run($req);
};

builder {
    enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' }
        "ReverseProxy";
    enable "Session",
        state   => 'Plack::Session::State::Cookie',
        store   => new Plack::Session::Store::File(dir => SESSIONS_PATH);
    enable "+EBox::Middleware::Auth";
    $app;
};

