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

# Class: EBox::Squid::Types::ListArchive
#

package EBox::Squid::Types::ListArchive;

use strict;
use warnings;

use base 'EBox::Types::File';

use EBox;
use EBox::Config;
use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::Sudo;

use Error qw(:try);
use File::Basename;

my $UNPACK_PATH = '/var/lib/zentyal/files/squid';

# Group: Private methods

sub _moveToPath
{
    my ($self) = @_;

    $self->SUPER::_moveToPath();

    my $path = $self->path();

    unless ($self->_fileIsArchive($path)) {
        throw EBox::Exceptions::External(__x('Invalid .tar.gz file: {f}', f => $path));
    }

    my $name = basename($path);
    my $dest = "$UNPACK_PATH/$name";
    $self->_extractArchive($path, $dest);
}

sub _fileIsArchive
{
    my ($self, $path) = @_;

    my $output = EBox::Sudo::root("/usr/bin/file -b $path");
    return ($output->[0] =~ m/^gzip compressed/);
}

sub _extractArchive
{
    my ($self, $path, $dir) = @_;

    EBox::Sudo::root("mkdir -p $dir",
                     "tar xzf $path -C $dir",
                     "chown -R root:ebox $dir",
                     "chmod -R o+r $dir");
}

# FIXME: what happens with this? when the file is removed?
sub _cleanArchive
{
    my ($self, $id) = @_;

    my $dir = $self->archiveContentsDir($id);
    EBox::Sudo::root("rm -rf $dir");
}

1;
