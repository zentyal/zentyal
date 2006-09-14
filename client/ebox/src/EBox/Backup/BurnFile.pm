package WriteCD;
# Description:
use strict;
use warnings;

use EBox;
use EBox::Gettext;
use EBox::Backup::OpticalDiscDrives;
use Perl6::Junction qw(all);
use File::Slurp qw(read_file);
use Error qw(:try);

use Readonly;
Readonly::Scalar my $MTAB_PATH=>'/etc/mtab';
Readonly::Scalar my $CDRECORD_PATH=>'/usr/bin/cdrecord';
Readonly::Scalar my $MKISOFS_PATH=>'/usr/bin/mkisofs';
Readonly::Scalar my $GROWISOFS_PATH=>'/usr/bin/growisofs';
Readonly::Scalar my $DVDRWFORMAT_PATH=>'/usr/bin/dvdrwformat';

sub burn
{
  my %params = @_;
  my $file   = $params{file};
  my $media  = $params{media};
  my $device = $params{device};
  
  _checkDevice($device);
  _checkDeviceForMedia($device, $media);
  _checkSize($file, $media);

  my $target = _setupBurningTarget($file, $media);

  if (_mediaUsesCdrecord($media)) {
    $device = _deviceForCdrecord($device);
  }

  blankMedia($device, $media);
  burnMedia($target, $device, $media);
}


sub _checkDeviceIsFree
{
  my ($device) = @_;

  if (!-e $device) {
    throw EBox::Exceptions::External(__x('{device} can not be found', device => $device))
  }


  open my $MTAB, ">$MTAB_PATH";
  try {
    while (my $line = <$MTAB>) {
       my ($mountedDev) = split '\s', $line, 2;
       if ($mountedDev eq $device) {
	 throw EBox::Exceptions::External(__x('{device} is mounted. Please, remove the disk', device => $device))    
       }
    }
  }
  otherwise {
    close $MTAB;
  };
  

}

sub _checkDeviceForMedia
{
  my ($device, $media) = @_;

  my $writersForMediaSub = EBox::Backup::OpticalDiscDrives->can("writersFor$media");
  defined $writersForMediaSub or throw EBox::Exceptions::Internal("'$media' is a unknown or non supported media type");
  my @writersForMedia = $writersForMediaSub->();
  if ($device ne all(@writersForMedia)) {
    throw EBox::Exceptions::External(__x('Device {dev} can not write media of type {media}', dev => $device, media => $media));
  }

}

sub _mediaUsesCdrecord
{
  my ($media) = @_;
  return $media eq  any('CDR', 'CDRW');
}

sub _mediaUsesGrowisofs
{
  my ($media) = @_;
  return $media eq  any('DVD', 'DVD-RW');
}


sub _setupBurningTarget
{
  my ($file, $media) = @_;

  if ( _mediaUsesCdrecord($media) ) {
    my $isoFile = EBox::Config::tmp() . '/backup.iso';
    my $mkisofsCommand = "$MKISOFS_PATH -V ebox-backup  -R -J  -o $isoFile $file";
    EBox::Sudo::command($mkisofsCommand);
    return $isoFile;
  }
  elsif ( _mediaUsesGrowisofs($media) ) {
    return $file;
  }
  else {
    throw EBox::Exceptions::Internal("No setup burning target provided for media $media");
  }
  
}


# this is for cdrecord device nightmare..
sub _deviceForCdrecord
{
  my ($device) = @_;

  # XXX Only IDE devices uspported for now!
#   my @output = EBox::Sudo::root("$CDRECORD_PATH -scanbus");
#     return $device if grep { !($_ =~ /\d) \*/ } @output;


  my  @output = EBox::Sudo::root("$CDRECORD_PATH dev=ATA: -scanbus");
  my $ideDevicesFound = grep { !($_ =~ /\d\) \*/) } @output;
  if (0 == $ideDevicesFound) {
    throw EBox::Exceptions::Internal("Can not found the device identified for cdrecord");
  }
  $device = 'ATA:' . $device;
  return $device;
}

sub blankMedia
{
  my ($device, $media) = @_;

  my @commands = ();
  if ($media eq  'CDRW') {
    push @commands, "$CDRECORD_PATH dev=$device  -tao  blank=fast";
  }

  return if (@commands == 0);

  EBox::info("Blanking media in $device");
  foreach my $command (@commands) {
    EBox::Sudo::root($command);
  }

}


sub burnMedia
{
  my ($target, $device, $media) = @_;

  my @commands = ();

  if ( _mediaUsesCdrecord($media) ) {
    push @commands, "$CDRECORD_PATH dev=$device  -tao $target";
  }
  elsif ( _mediaUsesGrowisofs($media) ) {
     push @commands, "$GROWISOFS_PATH -Z $device -R -J -V ebox-backup $target";
  }
  else {
    throw EBox::Excepions::Internal("No burning commands for media $media");    
  }


  EBox::info("Burning data in $device");
  foreach my $command (@commands) {
    EBox::Sudo::root($command);
  }
}


sub rootCommands
{
  my @commands=();
  return @commands;
}

1;
