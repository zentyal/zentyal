package EBox::Backup::FileBurner;
# Wrapper for burning methods
use strict;
use warnings;

use EBox;
use EBox::Gettext;
use EBox::Backup::OpticalDisc;
use EBox::Backup::OpticalDiscDrives;
use Perl6::Junction qw(all any);
use Error qw(:try);
use File::stat;

use Readonly;
Readonly::Scalar my $MTAB_PATH=>'/etc/mtab';
Readonly::Scalar my $CDRECORD_PATH=>'/usr/bin/cdrecord';
Readonly::Scalar my $MKISOFS_PATH=>'/usr/bin/mkisofs';
Readonly::Scalar my $GROWISOFS_PATH=>'/usr/bin/growisofs';
Readonly::Scalar my $DVDRWFORMAT_PATH=>'/usr/bin/dvd+rw-format';
Readonly::Scalar my $EJECT_PATH=>'/usr/bin/eject';


sub burn
{
  my %params = @_;
  my $file   = $params{file};
  my $device = exists $params{device} ? $params{device} : _chooseDevice();
  my $media;

  _checkDevice($device);
  $media = EBox::Backup::OpticalDisc::media($device);

  _checkDeviceForMedia($device, $media);
  _checkSize($file, $media);

  my $target = _setupBurningTarget($file, $media);

  if (_mediaUsesCdrecord($media)) {
    $device = _deviceForCdrecord($device);
  }

  blankMedia($device, $media);
  burnMedia($target, $device, $media);
  system $EJECT_PATH;
}

# see #158 for possible problems
sub burningAvailable
{
  my %info = %{EBox::Backup::OpticalDiscDrives::info() };
  my $candidate = undef;
  my $maxScore = 0;
  my @writingMedia = qw(CD-R CD-RW DVD-R);

  while (my $capabilities_r = values %info) {
    foreach my $capability (@writingMedia) {
      $capability = 'Can write ' . $capability;
      return 1 if ($capabilities_r->{$capability});
    }
  }

  return 0;
}

# the device choosed with the criterium of number of formats that it can write
# we also check for formats that we do not use becuase it may be a porxy for quality (and we are not be able to recognize dvd-rw capabilities see #158)
sub _chooseDevice
{
  my %info = %{EBox::Backup::OpticalDiscDrives::info() };
  my $candidate = undef;
  my $maxScore = 0;
  my @writingMedia = qw(CD-R CD-RW DVD-R DVD-RAM MRW RAM);

  while (my($dev, $capabilities_r) = each %info) {
    my $score = 0;
    foreach my $capability (@writingMedia) {
      $capability = 'Can write ' . $capability;
      $score += 1 if ($capabilities_r->{$capability});
    }
    if ($score > $maxScore) {
      $maxScore = $score;
      $candidate = $dev;
    }
  }

  if (!defined $candidate) {
    throw EBox::Exceptions::External(__('This system had not any recorder drive'));
  }
  
  return $candidate;
}

sub _checkDevice
{
  my ($device) = @_;

  if (!-e $device) {
    throw EBox::Exceptions::External(__x('{device} can not be found', device => $device))
  }


  open my $MTAB, "<$MTAB_PATH";
  try {
    while (my $line = <$MTAB>) {
       my ($mountedDev) = split '\s+', $line, 2;
       if ($mountedDev eq $device) {
	 throw EBox::Exceptions::External(__x('{device} is mounted. Please, remove the disk', device => $device))    
       }
    }
  }
  finally {
    close $MTAB;
  };
  

}

sub _checkDeviceForMedia
{
  my ($device, $media) = @_;

  my $normalizedMedia = $media;
  $normalizedMedia =~ s/-//;

  my $writersForMediaSub = EBox::Backup::OpticalDiscDrives->can("writersFor$normalizedMedia");
  defined $writersForMediaSub or throw EBox::Exceptions::Internal("'$media' is a unknown or non supported media type");
  my @writersForMedia = $writersForMediaSub->();
  if ($device ne all(@writersForMedia)) {
    throw EBox::Exceptions::External(__x('Device {dev} can not write media of type {media}', dev => $device, media => $media));
  }

}

sub _checkSize
{
  my ($file, $media) = @_;
  my $st = stat($file) ;
  defined $st or throw EBox::Exceptions::Internal("Can not stat $file");

  my $size = $st->size();
  my $mediaSize = EBox::Backup::OpticalDisc::sizeForMedia($media);

  if ($size >= $mediaSize) {
    throw EBox::Exceptions::External(__('The media has not sufficient capabilty for the data'));
  }
}
 

sub _mediaUsesCdrecord
{
  my ($media) = @_;
  return $media eq  any('CD-R', 'CD-RW');
}

sub _mediaUsesGrowisofs
{
  my ($media) = @_;
  return $media eq  any('DVD-R', 'DVD-RW');
}


sub _setupBurningTarget
{
  my ($file, $media) = @_;

  if ( _mediaUsesCdrecord($media) ) {
    my $isoFile = EBox::Config::tmp() . 'backup.iso';
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
# proposar to parse cdrecord:
#   my @output = EBox::Sudo::root("$CDRECORD_PATH -scanbus");
#     return $device if grep { !($_ =~ /\d) \*/ } @output;


  my  @output = EBox::Sudo::root("$CDRECORD_PATH dev=ATA: -scanbus");
  my $ideDevicesFound = grep { !($_ =~ /\d\) \*/) } @output;
  if (0 == $ideDevicesFound) {
    throw EBox::Exceptions::Internal("Can not found the device identified for cdrecord");
  }

  return $device;
}

sub blankMedia
{
  my ($device, $media) = @_;

  my $command;
  if ($media eq  'CD-RW') {
    $command = "$CDRECORD_PATH dev=$device  -tao  blank=fast";
  }
  elsif ($media eq 'DVD-RW') {
    $command = "$DVDRWFORMAT_PATH --blank $device";
  }

  return if (!defined $command);

  EBox::info("Blanking media in $device");
  EBox::Sudo::root($command);
}


sub burnMedia
{
  my ($target, $device, $media) = @_;

  my $command;
  if ( _mediaUsesCdrecord($media) ) {
    $command = "$CDRECORD_PATH dev=$device  -tao $target";
  }
  elsif ( _mediaUsesGrowisofs($media) ) {
     $command = "$GROWISOFS_PATH -Z $device -R -J -V ebox-backup $target";
  }
  else {
    throw EBox::Excepions::Internal("No burning commands for media $media");    
  }


  EBox::info("Burning data in $device");
  EBox::debug("Command used: $command");

  EBox::Sudo::root($command);
}


sub rootCommands
{
  my @commands=();
  push @commands, EBox::Backup::OpticalDisc::rootCommands();
  return @commands;
}

1;
