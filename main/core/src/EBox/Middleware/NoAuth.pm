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

package EBox::Middleware::NoAuth;

use parent qw(Plack::Middleware);

# Class: EBox::Middleware::NoAuth
#
#    Set login session as <EBox::Middleware::Auth> as anste
#

# Method: call
#
#   Set the requires as valid
#
# Overrides: <Plack::Middleware::call>
#
sub call
{
    my ($self, $env) = @_;

    $env->{'psgix.session.options'}->{change_id}++;
    $env->{'psgix.session'}{last_time} = time();
    $env->{'psgix.session'}{user_id} = $ENV{ZENTYAL_WEBADMIN_ENV};

    return $self->app->($env);
}

1;
