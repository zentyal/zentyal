# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
# Copyright (C) 2006-2008 Warp Networks S.L.
# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::Util::Lock;

use strict;
use warnings;

use EBox::Config;

use Fcntl qw(:flock);

sub lock
{
    my ($modulename) = @_;
    my $file = EBox::Config::tmp . "/" . $modulename . ".lock";
    open(LOCKFILE, ">$file") or
        throw EBox::Exceptions::Internal("Cannot open lockfile: $file");
    flock(LOCKFILE, LOCK_EX | LOCK_NB) or
        throw EBox::Exceptions::Lock($modulename);
}

sub unlock
{
    my ($modulename) = @_;
    my $file = EBox::Config::tmp . "/" . $modulename . ".lock";
    open(LOCKFILE, ">$file") or
        throw EBox::Exceptions::Internal("Cannot open lockfile: $file");
    flock(LOCKFILE, LOCK_UN);
    close(LOCKFILE);
}

1;
