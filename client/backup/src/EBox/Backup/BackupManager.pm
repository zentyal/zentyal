package EBox::Backup::BackupManager;
#  Module to control the Backup Manager program 
use strict;
use warnings;
use English qw(-no_match_vars);
use EBox::Config;
use EBox::Gettext;
use EBox::Sudo;
use EBox::FileSystem;
use HTML::Mason;
use Error qw(:try);

use EBox::Backup::OpticalDiscDrives;

use Readonly;
Readonly::Scalar my  $CONF_FILE => 'backup-manager.conf';
Readonly::Scalar my  $CONF_FILE_TEMPLATE => '/backup/backup-manager.conf.mas';

my %sizeByMedia = (
		   'DVD' => 4200,
		   'CDR'   => 650,
		   'CDRW'  => 650,
		  );

sub backup
{
  my (%params) = @_;

  my $bin = delete $params{bin};

  my $archiveDir = $params{archiveDir};
  EBox::FileSystem::cleanDir($archiveDir);



  if (exists $params{media}) {
    my $media = delete $params{media};
    my $device = _deviceForMedia($media);
    $params{burningDevice}  = $device;
    $params{burningDeviceForced}  = $device;
    $params{burningMedia}  =  $media;
    $params{burningMaxSize} = $sizeByMedia{$media};
  }
  else {
    $params{burn} = 0; # deactivate burn option if no media is specified
  }

  writeConfFile(%params);

  my $command = backupCommand($bin);
  EBox::Sudo::root($command);
}


sub _deviceForMedia
{
  my ($media) = @_;

  if (!exists $sizeByMedia{$media}) {
    throw EBox::Exceptions::Internal("Media type incorrect: $media");
  }

  my $mediaSubName = 'writersFor' . $media ;
  my $mediaSub     = EBox::Backup::OpticalDiscDrives->can($mediaSubName);
  if (!defined $mediaSub) {
    throw EBox::Exceptions::Internal("$mediaSubName not implemented in EBox::Backup::OpticalDiscDrives");
  }
  
  my @devices = $mediaSub->();
  if (@devices == 0) {
    throw EBox::Exceptions::External(__x("The system had not a writer for a {media}", media => $media));
  }
  ### XXX TODO: chose the best writer available
  my $chosenDevice =shift @devices;  
  return $chosenDevice;
}




sub backupCommand
{
  my ($bin) = @_;
  my $command =  "$bin --verbose --conffile " . confFile();
  return $command;
}


sub writeConfFile
{
  my (@params) = @_;
  
  my $confFile = confFile();
  my $oldUmask = umask;

  try {
    umask 0077;
    open my $FH, ">$confFile";

    my $interp = HTML::Mason::Interp->new(comp_root => EBox::Config::stubs,
					out_method => sub { $FH->print($_[0]) });
    my $comp = $interp->make_component(comp_file =>
				       EBox::Config::stubs . "/" . $CONF_FILE_TEMPLATE);
    $interp->exec($comp, @params);
    $FH->close();
  }
  finally {
    umask $oldUmask;
  };

}


sub confFile
{
  my $file = EBox::Config::tmp() . "/$CONF_FILE";
  return $file;
}


sub rootCommands
{
  my ($class, $bin) = @_;
  my @commands = ( backupCommand($bin) );
  return @commands;
}


1;
