# Copyright (C) 2009-2012 Zentyal S.L.
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


my %LOCKS;

sub lock
{
    my ($owner) = @_;
    my $file = _lockFile($owner);

    open($LOCKS{$owner}, ">$file") or
        throw EBox::Exceptions::Internal("Cannot open lockfile to lock: $file");
    flock($LOCKS{$owner}, LOCK_EX | LOCK_NB) or
        throw EBox::Exceptions::Lock($owner);
}

sub unlock
{
    my ($owner) = @_;
    my $file = _lockFile($owner);
    open($LOCKS{$owner}, ">$file") or
        throw EBox::Exceptions::Internal("Cannot open lockfile to unlock: $file");
    flock($LOCKS{$owner}, LOCK_UN);
    close($LOCKS{$owner});
    delete $LOCKS{$owner};
}

sub _lockFile
{
    my ($owner) = @_;
    return EBox::Config::tmp .  $owner . ".lock";
}

1;
