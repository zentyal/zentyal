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
my $REMOVE_LIST  = '/var/lib/zentyal/files/squid/removeList';
my $REMOVE_PREFIX = 'toremove.';

# validation for catogory directories
my %validParentDirs = (
    BL => 1,
    blacklists => 1,
);
my %validBasename = (
    domain => 1,
    urls   => 1,
   );

sub validParentDirs
{
    return \%validParentDirs;
}

sub validBasename
{
    return \%validBasename;
}

sub _paramIsValid
{
    my ($self) = @_;
    my $tmpPath = $self->tmpPath();
    if (not $self->_fileIsArchive($tmpPath)) {
        throw EBox::Exceptions::External(
            __('Supplied file is not a archive file')
           );
    }

    my $validContents;
    my $contents = EBox::Sudo::root("tar tzf '$tmpPath'");
    foreach my $line (@{ $contents  }) {
        chomp $line;
        my ($parentDir, $category, $basename) = split '/', $line, 3;
        if (exists $validParentDirs{$parentDir} and exists $validBasename{$basename}) {
            $validContents = 1;
            next;
        }
    }

    if (not $validContents) {
        throw EBox::Exceptions::External(
            __('Supplied archive file has not correct list structure')
           );
    }
}

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
    $self->_makeSquidDomainFiles($dest);
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

sub _makeSquidDomainFiles
{
    my ($self, $dir) = @_;
    my @files = @{ EBox::Sudo::root("find '$dir' -name domains") };
    foreach my $file (@files) {
        chomp $file;
        my $dirname = dirname($file);
        my $dstFile = $dirname . '/domains.squid';
        my $tmpFile = $dirname . '/tmp';
        EBox::Sudo::root(
            qq{cat '$file' | awk '{ print length, \$0 }' | sort -n | awk '{\$1=""; print \$0}' > '$tmpFile'},
            "cat '$tmpFile' | uniq -i > $dstFile",  # to remove duplicates
            "sed -e s/^././ -i '$dstFile'", # the first chracter is a blank
                                            # character
           );
    }
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
    my $squid = EBox::Global->getInstance(1)->modInstance('squid');
    my $state = $squid->get_state();

    my $path = $self->path();
    my $dir   = $self->archiveContentsDir();
    my $toRemove = $state->{'files_to_remove'};
    $toRemove or $toRemove = [];

    push @{$toRemove }, ($path , $dir);
    $state->{'files_to_remove'} = $toRemove;
    $squid->set_state($state);
}

sub commitAllPendingRemovals
{
    my ($self) = @_;
    my $squid = EBox::Global->getInstance(1)->modInstance('squid');
    my $state = $squid->get_state();

    my $toRemove = delete $state->{'files_to_remove'};
    $toRemove or return;
    foreach my $path (@{ $toRemove }) {
        my $rmCmd = "rm -rf '$path'";
        EBox::debug("REMOVe $rmCmd");
        EBox::Sudo::root($rmCmd);
    }

    $squid->set_state($state);
}

sub revokeAllPendingRemovals
{
    my ($self) = @_;
    my $squid = EBox::Global->getInstance(1)->modInstance('squid');
    my $state = $squid->get_state();
    delete $state->{'files_to_remove'};
    $squid->set_state($state);
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
