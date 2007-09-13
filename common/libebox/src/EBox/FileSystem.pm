package EBox::FileSystem;
use strict;
use warnings;


use base 'Exporter';
our @EXPORT_OK = qw(makePrivateDir cleanDir isSubdir dirDiskUsage dirFileSystem);

use Params::Validate;
use EBox::Validate;
use EBox::Gettext;

use constant FSTAB_PATH => '/etc/fstab';
use constant MTAB_PATH => '/etc/mtab';

# Group: Public procedures

# Procedure: makePrivateDir
#
#	Creates  a  directory owned by the user running this
#	process and with private permissions.
#
# Parameters:
#
#	path - The path of the directory to be created, if it exists it must
#	       already have proper ownership and permissions.
#
# Exceptions:
#
#	Internal & External - The path exists and is not a directory or has wrong
#		   ownership or permissions. Or it does not exist and 
#		   cannot be created.
sub makePrivateDir # (path)
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
    }
    else {
      $dir = $d;
    }

    if ( -e $dir) {
      if (! -d $dir) {
	throw EBox::Exceptions::Internal("$dir exists and is not a directory");
      }

      system "rm -rf $dir/*";
      if ($? != 0) {
	throw EBox::Exceptions::Internal "Error cleaning $dir: $!";
      }
    } 
    else {
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

# Function: permissionsFromStat
#     examines a File::stat  result object and extract the permissions value
#   		
# Parameters:
#      $stat - stat result object
#
# Returns:
#	the permissions as string
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
#	Int - the space used in block size units
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

  my $duCommand  ="/usr/bin/du --summarize --block-size=$blockSize $dir";

  my @duOutput = @{ EBox::Sudo::root($duCommand) };

  my ($blockCount) = split '\s', $duOutput[0], 2; # du outputs the block count first
  return $blockCount;
}


# Function: staticFileSystems
#
#   return static file systems information as seen in /etc/fstab
#
# Returns: 
#      a hash reference with the file system as key and a hash with his
#      properties as value.
#      The properties are: mountPoint, type, options, dump and pass
#      The properties have the same format that the fields in the fstab file
sub staticFileSystems
{
  return _fileSystems(FSTAB_PATH);
}


# Function: fileSystems
#
#   return mounted file systems information as seen in /etc/mtab
#
# Returns: 
#      a hash reference with the file system as key and a hash with his
#      properties as value.
#      The properties are: mountPoint, type, options, dump and pass
#      The properties have the same format that the fields in the fstab file
sub fileSystems
{
  return _fileSystems(MTAB_PATH);
}

# Group: Private procedures

sub _fileSystems
{
  my ($tabFile) = @_;

  my %fileSystems;
  
  my $FH;
  open $FH, $tabFile or
    throw EBox::Exceptions::Internal($tabFile . ' cannot be opened');
  while (my $line = <$FH>) {
    chomp $line;

    my ($lineData) = split '#', $line, 2; # remove comments

    next if not $lineData;
    next if ($lineData =~ m/^\s*$/);      # discard empty lines

    my ($fsys, $mpoint, $type, $options, $dump, $pass) = split '\s+', $lineData;

    
    $fileSystems{$fsys}->{mountPoint} = $mpoint;
    $fileSystems{$fsys}->{type} = $type;
    $fileSystems{$fsys}->{options} = $options;
    $fileSystems{$fsys}->{dump} = $dump;
    $fileSystems{$fsys}->{pass} = $pass;
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
#  Note:
#    - doesn't follow symlinks
#    - remember that subdirectories may be in anothe file system
sub dirFileSystem
{
  my ($dir) = @_;
  (-d $dir) or
    throw EBox::Exceptions::External(__x('Directory not found: {d}', d=>$dir));

  my %fileSystems = %{  fileSystems() };

  my $fsMatch     = undef;
  my $matchPoints = 0; 
  

  while (my ($fs, $attrs) = each %fileSystems) {
    my $mp = $attrs->{mountPoint};
    next if $mp eq'none';

    if (isSubdir($dir, $mp)) {
      my $points = length $mp; # lengt of mount point == more components in
                               # common. (Remember we don't follow symlinks)
      
      if ($points > $matchPoints) {
	$matchPoints = $points;
	$fsMatch     = $fs;
      }
      
    }
    
  }

  defined $fsMatch or
    throw EBox::Exceptions::Internal("Cannot found file system for directory $dir");

  return $fsMatch;
}

1;
