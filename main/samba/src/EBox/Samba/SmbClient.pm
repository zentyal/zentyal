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

package EBox::Samba::SmbClient;

use base 'Filesys::SmbClient';

use EBox::Gettext;
use EBox::Samba::AuthKrbHelper;

sub new
{
    my ($class, %params) = @_;

    my $krbHelper = new EBox::Samba::AuthKrbHelper(%params);
    my $flags = $class->SUPER::SMB_CTX_FLAG_USE_KERBEROS;
    my $self = $class->SUPER::new(username => $krbHelper->principal(),
                                  flags => $flags);
    $self->{krbHelper} = $krbHelper;
    bless ($self, $class);
    return $self;
}

sub read_file
{
    my ($self, $path, $mode) = @_;

    my @stat = $self->stat($path);
    if ($#stat) {
        my $fileSize = $stat[7];

        # Open the file
        my $fd = $self->open($path, $mode);
        if ($fd == 0) {
            throw EBox::Exceptions::Internal(__x('Could not open {x}: {y}',
                x => $path, y => $!))
        }

        my $buffer;
        my $chunkSize = 4096;
        my $pendingBytes = $fileSize;
        my $readBytes = 0;
        while ($pendingBytes > 0) {
            $chunkSize = ($pendingBytes < $chunkSize) ?
                          $pendingBytes : $chunkSize;
            my $ret = $self->read($fd, $chunkSize);
            if ($ret == -1) {
                throw EBox::Exceptions::Internal(__x('Could not read {x}: {y}',
                    x => $path, y => $!));
            }
            $buffer .= $ret;
            $readBytes += $chunkSize;
            $pendingBytes -= $chunkSize;
        }
        unless ($self->close($fd) == 0) {
            throw EBox::Exceptions::Internal(__x('Could not close {x}: {y}',
                x => $path, y => $!));
        }
        return $buffer;
    }
    throw EBox::Exceptions::Internal(__x('Could not stat file {x}',
        x => $path));
}

1;
