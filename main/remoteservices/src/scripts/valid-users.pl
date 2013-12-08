#!/usr/bin/perl -w

# Copyright (C) 2010-2012 Zentyal S.L.
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

# This script is intended to get those users that are valid in the system
# This script must be run as root

package EBox::RemoteServices::Audit::Password::ValidUsers;

use English '-no_match_vars';
use Perl6::Junction qw(any);
use User::pwent;

my @INVALID_SHELLS = qw(/bin/false /bin/true /sbin/nologin);

# Run only this script as root
exit(1) unless ($UID == 0);

while( my $sysUser = getpwent()) {
    next if ($sysUser->passwd() eq any(('*', '!')));
    my $shell = $sysUser->shell();
    next unless ($shell and $shell ne any(@INVALID_SHELLS));
    print $sysUser->name() . "\n";
}

1;
