package EBox::Backup::OpticalDiscDrives;
# module to get cdrom info from  /proc/sys/devices/cdrom
use strict;
use warnings;

use File::Slurp qw(read_file);
use Readonly;
Readonly::Scalar my $CDROM_INFO_PATH => '/proc/sys/dev/cdrom/info';

use EBox::Gettext;


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


sub  allowedMedia
{
  my @media;
  push @media, 'DVD-R' if writersForDVD() > 0;
  push @media, 'CD-R' if writersForCDR() > 0;
  push @media, 'CD-RW' if writersForCDRW() > 0;

  return @media;
}
 

1;
