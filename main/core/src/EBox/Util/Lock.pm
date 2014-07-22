# Copyright (C) 2009-2014 Zentyal S.L.
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

# Class: EBox::Util::Lock
#
#   Class to lock using flock. The lock can be blocking or not and
#   with a timeout.
#

use strict;
use warnings;

package EBox::Util::Lock;

use EBox::Config;
use EBox::Exceptions::Internal;
use EBox::Exceptions::Lock;

use Fcntl qw(:flock);

my %LOCKS;

# Procedure: lock
#
#     Lock the resource.
#
#     Use <unlock> to release it.
#
# Parameters:
#
#     resource - String the resource name for the lock realm
#
#     blocking - Boolean flag to indicate whether wait or not to get the resource
#
#     blockingTimeOut - Int if we want the lock exclusively, use this value
#                       value to wait for some time to get the lock
#                       Default: 0 (block until the resource is locked)
#
# Exceptions:
#
#     <EBox::Exceptions::Lock> -  if the lock request is non-blocking
#     and the resource is blocked or the blockTime has expired
#
#     <EBox::Exceptions::Internal> - if we cannot open the lock file
#
sub lock
{
    my ($resource, $blocking, $blockingTimeOut) = @_;

    $blockingTimeOut = 0 unless (defined($blockingTimeOut));
    $blocking = 0 unless (defined($blocking));

    my $file = _lockFile($resource);

    open($LOCKS{$resource}, ">$file") or
        throw EBox::Exceptions::Internal("Cannot open lockfile to lock: $file");

    if ($blocking) {
        if ($blockingTimeOut > 0) {
            eval {
                local $SIG{ALRM} = sub { die "Timed out\n"; };
                alarm($blockingTimeOut);
                flock($LOCKS{$resource}, LOCK_EX);
                ## Cancel the alarm if lock is got within $blockingTimeOut sec.
                alarm(0);
            }; if ($@) {
                if ($@ eq "Timed out\n") {
                    throw EBox::Exceptions::Lock("$resource after waiting $blockingTimeOut s");
                }
            }
        } else {
            flock($LOCKS{$resource}, LOCK_EX);
        }
    } else {
        flock($LOCKS{$resource}, LOCK_EX | LOCK_NB) or
          throw EBox::Exceptions::Lock($resource);
    }
}

# Procedure: unlock
#
#     Unlock the resource.
#
# Parameters:
#
#     resource - String the resource name for the lock realm
#
sub unlock
{
    my ($resource) = @_;
    my $file = _lockFile($resource);

    open($LOCKS{$resource}, ">$file") or
      throw EBox::Exceptions::Internal("Cannot open lockfile to unlock: $file");
    flock($LOCKS{$resource}, LOCK_UN);
    close($LOCKS{$resource});
    delete $LOCKS{$resource};
    unlink($file);

}

sub _lockFile
{
    my ($resource) = @_;
    return EBox::Config::tmp() .  $resource . ".lock";
}

1;
