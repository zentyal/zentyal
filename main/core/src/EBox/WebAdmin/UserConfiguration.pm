# Copyright (C) 2013 Zentyal S.L.
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

package EBox::WebAdmin::UserConfiguration;

use Apache2::RequestUtil;
use EBox::Exceptions::Internal;
use EBox::Config::Redis;

sub user
{
    my $r = Apache2::RequestUtil->request;
    my $user = $r->user;
    if (not defined $user) {

    }
    return $user;
}

sub _baseDir
{
    my ($user) = @_;
    return "/state/webadmin_users/$user/";
}

sub get
{
    my ($key) = @_;
    my $user = user();
    if (not $user) {
        return undef;
    }
    my $fullKey = _baseDir($user) . $key;
    return EBox::Config::Redis::instance()->get($fullKey);
}

sub set
{
    my ($key, $value) = @_;
    my $user = user();
    if (not $user) {
        throw EBox::Exceptions::Internal("Cannot se a use configuration value without a user logged in Zentyal");
    }
    my $fullKey = _baseDir($user) . $key;
    EBox::Config::Redis::instance()->set($fullKey, $value);
}

1;
