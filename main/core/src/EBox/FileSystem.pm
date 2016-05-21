# Copyright (C) 2006-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::FileSystem;

use base 'Exporter';

our @EXPORT_OK = qw(makePrivateDir cleanDir isSubdir dirDiskUsage dirFileSystem);
use Params::Validate;
use EBox::Validate;
use EBox::Gettext;
use EBox::Sudo;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use TryCatch;

use constant FSTAB_PATH => '/etc/fstab';
use constant MTAB_PATH => '/etc/mtab';

# Group: Public procedures

# Procedure: makePrivateDir
#
#       Creates  a  directory owned by the user running this
#       process and with private permissions.
#
# Parameters:
#
#       dir - The path of the directory to be created, if it exists it must
#              already have proper ownership and permissions.
#
# Exceptions:
#
#       Internal & External - The path exists and is not a directory or has wrong
#                  ownership or permissions. Or it does not exist and
#                  cannot be created.
sub makePrivateDir
{
    my ($dir) = @_;
    validate_pos(@_, 1);

    if (-e $dir) {
        if (  not -d $dir) {
            throw EBox::Exceptions::Internal( "Cannot create private directory $dir: file exists");
        }
        else {
            return EBox::Validate::isPrivateDir($dir, 1);
        }
    }

    mkdir($dir, 0700) or throw EBox::Exceptions::Internal("Could not create directory: $dir");
}

# Procedure: cleanDir
#
#       take action to assure that one or more directories have not
#       any file into them. To achieve so, these files may be deleted or
#       directories created
#
# Parameters:
#
#      dirs - Array list of directories
#
sub cleanDir
{
    my @dirs = @_;
    if (@dirs == 0) {
        throw EBox::Exceptions::Internal('cleanDir must be supplied at least a dir as parameter');
    }

    EBox::Validate::checkFilePath($_, 'directory')  foreach  (@dirs);

    foreach my $d (@dirs) {
        my $dir;
        my $mode = 0700;

        if (ref $d eq 'HASH' ) {
            $dir  = $d->{name};
            $mode = $d->{mode}
        } else {
            $dir = $d;
        }

        if (-e $dir) {
            if (! -d $dir) {
                throw EBox::Exceptions::Internal("$dir exists and is not a directory");
            }

            system "rm -rf '$dir'/*";
            if ($? != 0) {
                throw EBox::Exceptions::Internal "Error cleaning $dir: $!";
            }
        } else {
            mkdir ($dir, $mode) or  throw EBox::Exceptions::Internal("Could not create directory: $dir");
        }
    }
}

# Function: isSubdir
#
#    Find if a directory is a sub dir of another. A directory is
#    always a subdirectory of itself
#
# Parameters:
#
#    $subDir - String the directory which we want to check if it is a
#    sub directory. It must be a abolute path
#
#     $parentDir - the possible parent directory
#
# Returns:
#
#    boolean - Whether the first directory is a subdirectory of the
#    second or not
#
sub isSubdir
{
    my ($subDir, $parentDir) = @_;

    foreach ($subDir, $parentDir) {
        if (! EBox::Validate::checkAbsoluteFilePath($_)) {
            throw EBox::Exceptions::Internal("isSubdir can only called with absolute paths. Argumentes were ($subDir, $parentDir)))");
        }
    }

    # normalize paths
    $subDir .= '/';
    $parentDir .= '/';
    $subDir =~ s{/+}{/}g;
    $parentDir =~ s{/+}{/}g;

    return $subDir =~ m/^$parentDir/;
}

# Function: dirIsEmpty
#
#    Find if a directory is empty or not. Not existent directories are considered empty.
#
#  Returns:
#       - boolean
sub dirIsEmpty
{
    my ($dir) = @_;
    # ls command will fail with non-zero if they are not files udner the
    # directory
    EBox::Sudo::silentRoot("ls $dir/*");
    return $? != 0;
}

# Function: unusedFileName
#
# return the first unused fiel name in the form '$file.N' while N are
# consecutive numbers.
# If N == 0 the suffix is ignored.
# Holes in numbers are reused.
sub unusedFileName
{
    my ($file) = @_;
    defined $file or
        throw EBox::Exceptions::MissingArgument('file');

    my $name = $file;
    my $suffix = 0;
    while (EBox::Sudo::fileTest('-e', $name)) {
        $suffix += 1;
        if ($suffix > 100) {
            throw EBox::Exceptions::Internal("Maximum suffix name reached: $name");
        }
        $name = $file . '.' . $suffix;
    }

    return $name;
}

# Function: permissionsFromStat
#     examines a File::stat  result object and extract the permissions value
#
# Parameters:
#      $stat - stat result object
#
# Returns:
#       the permissions as string
#
sub permissionsFromStat
{
    my ($stat) = @_;
    return sprintf("%04o", $stat->mode & 07777);
}

# Function: dirDiskUsage
#
#     Get the space used up by the files and subdirectories in a
#     directory
#
# Parameters:
#
#      dir       - String directory
#      blockSize - Int size of the block in bytes. Default: 1 Kb
#
# Returns:
#
#       Int - the space used in block size units
#
sub dirDiskUsage
{
    my ($dir, $blockSize) = @_;
    defined $dir or
        throw EBox::Exceptions::MissingArgument('dir');
    defined $blockSize or
        $blockSize = 1024;

    (-d $dir) or
        throw EBox::Exceptions::External(__x('Directory not found: {d}', d => $dir));

    my $duCommand = "/usr/bin/du --summarize --block-size=$blockSize '$dir'";

    my @duOutput = @{ EBox::Sudo::silentRoot($duCommand) };

    my ($blockCount) = split '\s', $duOutput[0], 2; # du outputs the block count first
        return $blockCount;
}

# Function: staticFileSystems
#
#      Return static file systems information as seen in /etc/fstab
#      file
#
#  Parameters:
#    bind - whether to include or not bind filesystems (name, default false)
#
# Returns:
#
#      Hash ref - with the file system as key and a hash with its
#      properties as value.
#
#      The properties are: mountPoint, type, options, dump and pass
#      The properties have the same format that the fields in the
#      fstab file.
#
sub staticFileSystems
{
    return _fileSystems(FSTAB_PATH, @_);
}

# Function: fileSystems
#
#   return mounted file systems information as seen in /etc/mtab
#
#  Parameters:
#    bind - whether to include or not bind filesystems (name, default false)
#
# Returns:
#      a hash reference with the file system as key and a hash with his
#      properties as value.
#      The properties are: mountPoint, type, options, dump and pass
#      The properties have the same format that the fields in the fstab file
sub fileSystems
{
    return _fileSystems(MTAB_PATH, @_);
}

#  Function: partitionsFileSystems
#
#   return the file system data for mounted disk partitions
#
# Parameters:
#  includeRemovables - include removable FS (now detected as FS under /media)
#
# Returns:
#      a hash reference with the file system as key and a hash with his
#      properties as value.
#      The properties are: mountPoint, type, options, dump and pass
#      The properties have the same format that the fields in the fstab file
#
my %noDeviceFs = (
    proc => 1,
    devpts => 1,
    tmpfs => 1,
    securityfs => 1,
    selinuxfs => 1,
    fuse => 1,
    devtmpfs => 1,
    binfmt_misc => 1,
    gvfs => 1,
);

sub partitionsFileSystems
{
    my ($includeRemovable) = @_;

    my %fileSys = %{  fileSystems() };

    while (my ($fs, $attrs) = each %fileSys) {
        # remove non-device filesystems
        unless ($fs =~ m{^/}) {
                delete $fileSys{$fs};
                next;
        }

        my $type = $attrs->{type};
        if (exists $noDeviceFs{$type} and $noDeviceFs{$type}) {
                delete $fileSys{$fs};
                next;
        } elsif ($type =~ /^fuse\./) {
            # ignore any fuse files system
            delete $fileSys{$fs};
            next;
        }

        if (not $includeRemovable) {
            # remove removable media files
            my $mpoint = $attrs->{mountPoint};
            if ($mpoint =~ m{^/media/}) {
                delete $fileSys{$fs};
                next;
            }
        }
    }

    return \%fileSys;
}

# Group: Private procedures

sub _fileSystems
{
    my ($tabFile, %options) = @_;
    my $includeBind = $options{bind};
    my %fileSystems;

    my $FH;
    open $FH, $tabFile or
      throw EBox::Exceptions::Internal($tabFile . ' cannot be opened');
    while (my $line = <$FH>) {
        chomp $line;

        my ($lineData) = split '#', $line, 2; # remove comments

        next if not $lineData;
        next if ($lineData =~ m/^\s*$/); # discard empty lines

        my ($fsys, $mpoint, $type, $options, $dump, $pass) = split '\s+', $lineData;
        if ($fsys eq 'none') {
            # none file sys are ignored by now
            next;
        }

        my @options = split /,/, $options;
        my $bind = grep { $_ eq 'bind' } @options;
        if ($bind and not $includeBind) {
            # ignoring binded filesystems
            next;
        }

        my $attrs = {
            mountPoint => $mpoint,
            type => $type,
            options => $options,
            dump => $dump,
            pass => $pass,
        };

        $fileSystems{$fsys} = $attrs;
    }

    close $FH or
      throw EBox::Exceptions::Internal('Cannot properly close ' . FSTAB_PATH);

    return \%fileSystems;
}

#  Function: dirFileSystem
#
#  Returns:
#     the file system in which the directory resides
#
sub dirFileSystem
{
    my ($dir) = @_;
    (-d $dir) or
        throw EBox::Exceptions::External(__x('Directory not found: {d}', d=>$dir));

    my $fs;
    my $dirToCheck = $dir;
    my $realFSFound    = 0;
    while (not $realFSFound) {
        my $dfOutput = EBox::Sudo::root("df '$dirToCheck'");
        my $infoLine =$dfOutput->[1];
        chomp $infoLine;
        ($fs) = split '\s+', $infoLine;
        defined $fs or
            throw EBox::Exceptions::Internal("Cannot find file system for directory $dir");
        if (EBox::Sudo::fileTest('-d', $fs)) {
            # this is a bind fs..
            $dirToCheck = $fs;
        } else {
            $realFSFound = 1;
        }
    }

    return $fs;
}

# Method: mountPointIsMounted
#
#  Check if something is mounted in a path, it does not
#  discriminate between filesys types ( partitionsFileSystems ignores
#  no-device file systems)
#
#  Returns:
#
#    bool - whether something is mounted in the mount point
#
# Limitations:
#   -it ignores bind mounts
sub mountPointIsMounted
{
    my ($mp) = @_;
    my %fileSys = %{  fileSystems() };
    foreach my $fsAttr (values %fileSys) {
        if ($mp eq $fsAttr->{mountPoint}) {
            return 1;
        }
    }

    return 0;
}

1;
