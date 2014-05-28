# Copyright (C) 2014 Zentyal S.L.
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

package EBox::WebAdmin::Middleware::SubAppAuth;

use parent qw(Plack::Middleware);

# Class: EBox::Middleware::SubAppAuth
#
#    Set login session as <EBox::Middleware::Auth> do if validation
#    happens. This only applies to <EBox::WebAdmin::PSGI::subApps>.
#

# Method: call
#
#   Set the requires as valid if condition applies
#
# Overrides: <Plack::Middleware::call>
#
sub call
{
    my ($self, $env) = @_;

    my $subApp = EBox::WebAdmin::PSGI::subApp(url => $env->{PATH_INFO}, validation => 1);
    if ($subApp) {
        if (EBox::WebAdmin::PSGI::validate($subApp, $env)) {
            # FIXME?: Do this only if session is not set?
            $env->{'psgix.session.options'}->{change_id}++;
            $env->{'psgix.session'}{last_time} = time();
            $env->{'psgix.session'}{user_id} = $subApp->{userId};
            $env->{'zentyal'}->{'webadminsubapp'} = $subApp->{url};
        } else {
            # Do logout
            if (exists $env->{'psgix.session'}) {
                delete $env->{'psgix.session'}{user_id};
                delete $env->{'psgix.session'}{last_time};
            }
            if (exists $env->{'zentyal'}) {
                delete $env->{'zentyal'}->{'webadminsubapp'};
            }
        }
    }
    return $self->app->($env);
}

1;
