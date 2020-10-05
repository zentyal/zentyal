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
use EBox::CGI::Run;
use EBox::Gettext;
use EBox::Middleware::NoAuth;
use EBox::WebAdmin::PSGI;

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

    local $SIG{__WARN__} = sub { EBox::warn($_[0]) };

    my $req = Plack::Request->new($env);
    return EBox::CGI::Run->run($req);
};

my $builder = new Plack::Builder();
$builder->add_middleware("+EBox::Middleware::UnhandledError");
$builder->add_middleware("ReverseProxy");
$builder->add_middleware("Session",
                         state   => 'Plack::Session::State::Cookie',
                         store   => new Plack::Session::Store::File(dir => SESSIONS_PATH));
$builder->add_middleware("+EBox::WebAdmin::Middleware::SubAppAuth");
$builder->add_middleware_if(sub { exists($ENV{ZENTYAL_WEBADMIN_ENV}) and ($ENV{ZENTYAL_WEBADMIN_ENV} eq 'anste') },
                            "+EBox::Middleware::NoAuth");

# TODO: Check if is commerciall
$builder->add_middleware("+EBox::Middleware::AuthRemote", app_name => 'webadmin');
$builder->add_middleware("+EBox::Middleware::AuthPAM", app_name => 'webadmin');
foreach my $appConf (@{EBox::WebAdmin::PSGI::subApps()}) {
    $builder->mount($appConf->{url} => $appConf->{app});
}
$builder->mount('/' => $app);
$builder->to_app();

