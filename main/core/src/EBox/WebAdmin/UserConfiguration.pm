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

use EBox::Exceptions::Internal;
use EBox::Config::Redis;

sub _fullKey
{
    my ($user, $key) = @_;
    my $fullKey =  "user-conf/$user";
    $fullKey .= $key;
    $fullKey =~ s{//+}{/}g;
    return $fullKey;
}

sub get
{
    my ($user, $key) = @_;
    if (not $user) {
        return undef;
    }
    my $fullKey = _fullKey($user, $key);
    return EBox::Config::Redis::instance()->get($fullKey);
}

sub set
{
    my ($user, $key, $value) = @_;
    unless ($user) {
        throw EBox::Exceptions::Internal("Cannot set user configuration values without a user logged in Zentyal");
    }
    my $fullKey = _fullKey($user, $key);
    EBox::Config::Redis::instance()->set($fullKey, $value);
}

1;
