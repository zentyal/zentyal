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
use strict;
use warnings;

package EBox::Squid::Types::ListArchive;
use base 'EBox::Types::File';

use EBox;
use EBox::Config;
use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::Sudo;
use EBox::FileSystem;

use Error qw(:try);
use File::Basename;


my $UNPACK_PATH = '/var/lib/zentyal/files/squid/categories';
my $REMOVE_PREFIX = 'toremove.';
# Group: Private methods

sub _moveToPath
{
    my ($self) = @_;
    # assure that base dest dir exists
    my $dir = dirname($self->path());
    if (not EBox::Sudo::fileTest('-e', $dir)) {
        EBox::Sudo::root("mkdir -p '$dir'");
    }

    $self->SUPER::_moveToPath();

    my $path = $self->path();

    unless ($self->_fileIsArchive($path)) {
        throw EBox::Exceptions::External(__x('Invalid .tar.gz file: {f}', f => $path));
    }

    my $dest = $self->archiveContentsDir();
    $self->_extractArchive($path, $dest);
}

sub _fileIsArchive
{
    my ($self, $path) = @_;

    my $output = EBox::Sudo::root("/usr/bin/file -b '$path'");
    return ($output->[0] =~ m/^gzip compressed/);
}

sub _extractArchive
{
    my ($self, $path, $dir) = @_;

    EBox::Sudo::root("mkdir -p '$dir'",
                     "tar xzf '$path' -C '$dir'",
                     "chown -R root:ebox '$dir'",
                     "chmod -R o+r '$dir'");
}

sub archiveContentsDir
{
    my ($self) = @_;
    my $path = $self->path();
    my $name = basename($path);
    return "$UNPACK_PATH/$name";
}

sub _removalDir
{
    my ($self) = @_;
    my $path = $self->archiveContentsDir();
    my $dirname = dirname($path);
    my $basename = $REMOVE_PREFIX . basename($path);
    return $dirname . '/' . $basename;
}


sub markArchiveContentsForRemoval
{
    my ($self, $id) = @_;

    my $dir        = $self->archiveContentsDir();
    my $removalDir = $self->_removalDir();
    if (EBox::Sudo::fileTest('-e', $removalDir)) {
        my $fallbackPath = EBox::FileSystem::unusedFileName("$removalDir.old");
        EBox::error("When moving $dir to temporal pre removal directory $removalDir , we found that it exists. We will move it to $fallbackPath to be able to continue");
        EBox::Sudo::root("mv -f '$removalDir' '$fallbackPath'");
    }
    EBox::Sudo::root("mv -f '$dir' '$removalDir'");

    # XXX work around until framework again support removal and commits of the
    # files themselves. This code is repititive  but since it is
    # temporal i dont extract it to a method
    my $path = $self->path();
    my $dirname = dirname($path);
    my $basename = basename($path);
    my $removalPath = $dirname . '/' . $REMOVE_PREFIX . $basename;
    if (EBox::Sudo::fileTest('-e', $removalPath)) {
        my $fallbackPath = EBox::FileSystem::unusedFileName("$removalPath.old");
        EBox::error("When moving $dir to temporal pre removal file $removalDir , we found that it exists. We will move it to $fallbackPath to be able to continue");
        EBox::Sudo::root("mv -f '$removalPath' '$fallbackPath'");
    }
    EBox::Sudo::root("mv -f '$path' '$removalPath'");
}

sub commitAllPendingRemovals
{
    my ($self) = @_;
    my $path = $UNPACK_PATH . "/$REMOVE_PREFIX*";
    EBox::Sudo::root("rm -rf $path");

    # XXX work around until framework again support removal and commits of the
    # files themselves. This code is repititive  but since it is
    # temporal i dont extract it to a method
    my $LIST_FILE_DIR = '/etc/dansguardian/extralists'; # from CategorizedLists
                                                        # model
    $path = $LIST_FILE_DIR . "/$REMOVE_PREFIX*";
    EBox::Sudo::root("rm -rf $path");
}

sub revokeAllPendingRemovals
{
    my ($self) = @_;
    my $path = $UNPACK_PATH . "/$REMOVE_PREFIX*";
    my @dirs = glob($path);
    foreach my $dir (@dirs) {
        my $dirname = dirname($dir);
        my $basename = basename($dir);
        $basename =~ s/^$REMOVE_PREFIX//;
        EBox::debug("basenameAfter $basename");
        my $newPath = $dirname . '/' . $basename;
        EBox::debug("$dir -> $newPath");
        if (EBox::Sudo::fileTest('-e', $newPath)) {
            my $replacePath = EBox::FileSystem::unusedFileName("$dir.old");
            EBox::error("Cannot restore $newPath from $dir because it already exists. $dir will be moved to $replacePath");
            $newPath = $replacePath;
        }
        EBox::Sudo::root("mv -f '$dir' '$newPath'");
    }

    # XXX work around until framework again support removal and commits of the
    # files themselves. This code is repititive  but since it is
    # temporal i dont extract it to a method
    my $LIST_FILE_DIR = '/etc/dansguardian/extralists'; # from CategorizedLists
                                                        # model
    $path = $LIST_FILE_DIR . "/$REMOVE_PREFIX*";
    @dirs = glob($path);
    foreach my $dir (@dirs) {
        my $dirname = dirname($dir);
        my $basename = basename($dir);
        $basename =~ s/^$REMOVE_PREFIX//;
        EBox::debug("basenameAfter $basename");
        my $newPath = $dirname . '/' . $basename;
        EBox::debug("$dir -> $newPath");
        if (EBox::Sudo::fileTest('-e', $newPath)) {
            my $replacePath = EBox::FileSystem::unusedFileName("$dir.old");
            EBox::error("Cannot restore $newPath from $dir because it already exists. $dir will be moved to $replacePath");
            $newPath = $replacePath;
        }
        EBox::Sudo::root("mv -f '$dir' '$newPath'");
    }
}

sub unpackPath
{
    return $UNPACK_PATH;
}

sub toRemovePrefix
{
    return $REMOVE_PREFIX;
}


1;
