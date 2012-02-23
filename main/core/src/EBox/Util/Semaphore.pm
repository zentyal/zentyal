# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::Util::Semaphore;

use strict;
use warnings;

use EBox::Exceptions::Internal;

my $IPC_CREAT = 00001000;
my $IPC_EXCL = 00002000;
my $SEM_UNDO = 0x1000;
my $IPC_NOWAIT = 00004000;

sub init
{
    my ($class, $key) = @_;

    my $sem = semget($key, 0, 0);
    unless ($sem) {
        # FIXME: better permissions?
        $sem = semget($key, 1, $IPC_CREAT | $IPC_EXCL | 0666) or
            throw EBox::Exceptions::Internal('Error trying to get semaphore');
    }

    my $self = {};
    bless $self, $class;

    $self->{sem} = $sem;

    return $self;
}

sub signal
{
    my ($self) = @_;

    semop($self->{sem}, pack("s!s!s!", 0, -1, $SEM_UNDO)) or
        throw EBox::Exceptions::Internal('Error on semaphore signal');
}

sub wait
{
    my ($self) = @_;

    semop($self->{sem}, pack("s!s!s!", 0, 0, $SEM_UNDO) . pack("s!3", 0, 1, $SEM_UNDO)) or
        throw EBox::Exceptions::Internal('Error on semaphore signal');
}

1;
