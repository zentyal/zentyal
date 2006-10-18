package EBox::Backup::OpticalDiscDrives;
# module to get cdrom info from  /proc/sys/devices/cdrom
use strict;
use warnings;

use File::Slurp qw(read_file);
use Perl6::Junction qw(all);
use EBox::Gettext;
use EBox::Sudo;
use EBox::Backup::RootCommands;

use Readonly;
Readonly::Scalar my $CDROM_INFO_PATH => '/proc/sys/dev/cdrom/info';
Readonly::Scalar my $FSTAB_PATH      => '/etc/fstab';
Readonly::Scalar my $MTAB_PATH      => '/etc/mtab';


sub info
{
  if (! -e $CDROM_INFO_PATH) {
    throw EBox::Exceptions::External (__x('Unable to find {path}. Make sure that the cdrom driver is compiled in your kerner or loaded as module', path -> $CDROM_INFO_PATH));
  }
  if (! -r $CDROM_INFO_PATH) {
    throw EBox::Exceptions::External (__x('Unable to read {path}.', path -> $CDROM_INFO_PATH));
  }

  my @infoFile = read_file($CDROM_INFO_PATH);

  # we have not use for the first two lines
  shift @infoFile;
  shift @infoFile;
  # chomp remaining lines
  chomp @infoFile;

  my %info;
  my @names;
  
  my $driveNameLine = shift @infoFile;
  if (! $driveNameLine =~ m{^drive name:} ) {
    throw EBox::Exceptions::Internal("Parse error in $CDROM_INFO_PATH: supposed drive name line does not match");
  }
  (undef, undef,  @names) = split '\s+', $driveNameLine; # get the drive names
  @names = map { '/dev/' . $_ } @names;
  $info{$_} = {} foreach @names; # create entries in  info foreach drive and append /dev/

  foreach my $line (@infoFile) {
    next if $line =~ m{^\s*$};
    
    my ($section, $valuesString) = split ':', $line, 2;
    my @values = split '\s+', $valuesString;
    shift @values; # remove empty leading field

    (@values == @names) or throw EBox::Exceptions::Internal("Error parsing $CDROM_INFO_PATH: number of elements and values in section $section don't match");
    foreach my $n (0 .. scalar @names -1) {
      $info{$names[$n]}->{$section} = $values[$n];
    }
  }

  return \%info;
}


sub writersForDVDR
{
  return _selectByCapability('Can write DVD-R');
}


# we assume that DVD-R capable are also DVD-RW capable (limitation found in cdrom/info file)
sub writersForDVDRW
{
  return _selectByCapability('Can write DVD-R');
}

sub writersForCDR
{
  return _selectByCapability('Can write CD-R');
}

sub writersForCDRW
{
  return _selectByCapability('Can write CD-RW');
}


sub _selectByCapability
{
  my ($capability) = @_;
  my @selectedDevices;

  my %deviceInfo = %{ info()  };
  while (my ($device, $capabilities_r) = each %deviceInfo) {
    if ($capabilities_r->{$capability}) {
      push @selectedDevices, $device;
    }
  }

  return @selectedDevices;
}

# we assume that DVD-R capable are also DVD-RW capable (limitation found in cdrom/info file)
sub  allowedMedia
{
  my @media;
  push @media, 'DVD-R' if writersForDVD() > 0;
  push @media, 'DVD-RW' if writersForDVD() > 0;
  push @media, 'CD-R' if writersForCDR() > 0;
  push @media, 'CD-RW' if writersForCDRW() > 0;

  return @media;
}
 



#
# Function: searchFileInDiscs
#
#   	Search a file in the optical drive's disks. If the file is in a unmounted disk, the disk will be mounted and it is developer responsability to unmount it when appropiate.
#
# Parameters:
#
#    file - target file name, relative to the mount point of the disk's file system
#
# Returns:
#	A hash that contains the following keys:
#         file   - path to the file
#         device - the device file of the drive that has the disc where the file resides
#
# Limitations:
#      we search only in optical disc drives that are user mountable
#      if there are various drives and discs with the target file name, only one of them will be chosen. The choose criteria es undefined.
# 
sub searchFileInDiscs
{
  my ($file) = @_;

  my @fstab = read_file($FSTAB_PATH);
  my @mtab  = read_file($MTAB_PATH);
  my @devices = keys %{ info() };
  my $allDevices = all(@devices);

  foreach my $fstabLine (@fstab) {
    my ($device, $mountPoint, $type, $options) = split '\s+', $fstabLine;

    
    next if $device ne $allDevices;
    if ( !($options =~ m/[\s,]user[\s,]/) ) {
      EBox::debug("device $device skipped because it has no user option set");
      next;
    }
    
    my $wasMounted = grep {m/^$device/} @mtab;
    if (!$wasMounted) {
      system("/bin/mount $mountPoint");
      next if ($? != 0); 
    }

    my $filePath = "$mountPoint/$file";
    if ( -f $filePath) {
      if ( -r $filePath ) {
	return { file => $filePath,  device => $device  };
      }
      else {
	EBox::debug("$file found in $filePath but is no tedeable. Skipping");	
      }
    }

    if (!$wasMounted) {
      EBox::Sudo::command("/bin/umount $mountPoint");
    }
  }

  return undef;
}


#
# Function: ejectDisc
#
#   	tries to eject the disc from the device	
#
# Parameters:
#
#   $device - device file for the drive
#
# Returns:
#	
#   true if the operation was successful, false if the operation failed
# 
sub ejectDisc
{
    my ($device) = @_;
    EBox::Sudo::rootWithoutException("$EBox::Backup::RootCommands::EJECT_PATH  " . $device);
    
    return ($? == 0); #$? was set by rootWithoutException
}

1;
