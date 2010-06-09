# Copyright (C) 2009-2010 eBox Technologies S.L.
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Class: EBox::CaptivePortalHelper

package EBox::CaptivePortalHelper;

use strict;
use warnings;

use EBox;
use EBox::Util::Lock;
use EBox::Sudo;

use Error qw(:try);
use YAML::Tiny;
use File::Basename;

use constant CAPTIVEPORTAL_DIRECTORY => '/var/lib/ebox-usercorner/captiveportal/';
use constant REFRESH_INTERVAL => 60;

# Method: interval
#
#   Returns the interval in seconds between two pop-up refreshes
#
sub interval
{
    return REFRESH_INTERVAL;
}

# Method: userInfo
#
#    Returns the information of logged in user
#
sub userInfo
{
    my ($user) = @_;

    my $file = CAPTIVEPORTAL_DIRECTORY . $user;
    if (! -f $file) {
        return undef;
    }

    if (_isStale($user)) {
        return undef;
    }

    my $info;
    try {
        my $yaml = YAML::Tiny->read($file);
        $info = $yaml->[0];
    } otherwise {
        EBox::error("Error reading YAML file $file");
    };
    return $info;
}
# Method: userIP
#
#    Returns the IP a user logged in from or undef if it's not logged in
#
sub userIP
{
    my ($user) = @_;
    my $info = userInfo($user);
    my $ip;
    if ($info) {
        $ip = $info->{'ip'};
    }
    return $ip;
}

sub addUniqueRule
{
    my ($chain, $user, $rule) = @_;
    my $output = EBox::Sudo::root('/sbin/iptables -L -n --line-numbers');
    my $inchain = 0;
    for my $line (@{$output}) {
        if ($line =~ m/^Chain ([A-Za-z]+) /) {
            if ($1 eq $chain) {
                $inchain = 1;
            } else {
                $inchain = 0;
            }
        } else {
            if ($inchain) {
                if($line =~ m/^(\d+) .*user:$user /) {
                    my $num = $1;
                    EBox::Sudo::root("/sbin/iptables -D $chain $num");
                }
            }
        }
    }
    EBox::Sudo::root("/sbin/iptables -I $chain $rule -m comment --comment 'user:$user'");
}

sub addRule
{
    my ($user) = @_;
    my $ip = userIP($user);
    if($ip) {
        EBox::Util::Lock::lock('firewall');
        EBox::info("Adding rule for user $user with IP $ip");
        my $rule = "-s $ip -j RETURN";
        addUniqueRule("icaptive", $user, $rule);
        addUniqueRule("fcaptive", $user, $rule);
        EBox::Util::Lock::unlock('firewall');
    }
}

sub removeRule
{
    my ($user) = @_;
    my $ip = userIP($user);
    if($ip) {
        EBox::Util::Lock::lock('firewall');
        EBox::info("Removing rule for user $user with IP $ip");
        EBox::Sudo::root("/sbin/iptables -D icaptive -s $ip -m comment --comment 'user:$user' -j RETURN");
        EBox::Sudo::root("/sbin/iptables -D fcaptive -s $ip -m comment --comment 'user:$user' -j RETURN");
        EBox::Util::Lock::unlock('firewall');
    }
}

sub _isStale
{
    my ($user) = @_;

    my $file = CAPTIVEPORTAL_DIRECTORY . $user;
    my $time = 0;
    try {
        my $yaml = YAML::Tiny->read($file);
        $time = $yaml->[0]->{'time'};
    } otherwise {};
    if (($time + (2*interval())) < time()) {
        return 1;
    } else {
        return undef;
    }
}

# Method: currentUsers
#
sub currentUsers
{
    my @users;
    for my $file (glob(CAPTIVEPORTAL_DIRECTORY . '*')) {
        my $user = basename($file);
        my $info = userInfo($user);
        if($info) {
            push(@users, $info);
        }
    }
    return \@users;
}

sub removeStaleUsers
{
    for my $file (glob(CAPTIVEPORTAL_DIRECTORY . '*')) {
        my $user = basename($file);
        if (_isStale($user)) {
            removeRule($user);
            EBox::Sudo::root("rm -f $file");
        }
    }
    return 1;
}

1;
