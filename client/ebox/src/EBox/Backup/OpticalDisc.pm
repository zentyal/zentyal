package EBox::Backup::OpticalDisc;
# module to get information about the disk inserted in the writer device
use strict;
use warnings;

use EBox::Sudo;
use EBox::Gettext;
use EBox::Backup::RootCommands;
use Readonly;
Readonly::Scalar my $CD_SIZE   => 681000000; # we assume 650Mb instead 700 to err in the safe side
Readonly::Scalar my $DVD_SIZE  => 4380000000; # likewise we assume 4.38 GiB



sub sizeForMedia
{
  my ($media) = @_;

  return $CD_SIZE  if ($media eq 'CD-R')  or ($media eq 'CD-RW');
  return $DVD_SIZE if ($media eq 'DVD-R') or ($media eq 'DVD-RW');
  
  throw EBox::Exceptions::Internal("Incorrect media or size data unknown: $media");
}

# return type or 'no_disc' if device is empey. exception when error
# 
sub media
{
  my ($dev) = @_;

  my $info;
  $info = infoFromDvdMediaInfo($dev);
  return $info if $info;

  $info = infoFromCdrecord($dev);
  return $info;
}


sub infoFromDvdMediaInfo
{
  my ($dev) = @_;

  my @output =  @{ EBox::Sudo::rootExceptionSafe("$EBox::Backup::RootCommands::DVDMEDIAINFO_PATH $dev 2>&1")};



  if (grep { m/no media mounted/ }  @output) {
    
    return 'no_disc';
  }
  elsif (grep {m/non-DVD media mounted/} @output) {
    return undef;
  }

  my ($mountedMediaLine) = grep {m/Mounted Media:/} @output;
  if (!$mountedMediaLine) {
    throw EBox::Exceptions::External(__x("Unable to recognize the mounted DVD media. output {output}", output => "@output"));
  }

  if ($mountedMediaLine =~ m/(DVD.*?)\s/) {
    my $media = $1;
    return $media;
  }
  else {
    throw EBox::Exceptions::External(__x('Unable to recognize the mounted DVD media: error parsing mediainfo output'));
  }
}


sub infoFromCdrecord
{
  my ($dev) = @_;

  my $atipCmd = "$EBox::Backup::RootCommands::CDRECORD_PATH  -atip dev=$dev";
  my @output = @{ EBox::Sudo::root($atipCmd) };


  if (grep { m/medium not present/ } @output) {
    return 'no_disc';
  }

  if (!grep {m/ATIP info from disk:/} @output) {
    throw EBox::Exceptions::External(__('Can not recognize media: unable to read ATIP info from disc'));
  }
  
  if (grep {m/Is erasable/} @output) {
    return 'CD-RW';
  }

  if (grep {m/Is not erasable/} @output) {
    return 'CD-R';
  }

    throw EBox::Exceptions::External(__('Can not recognize media'));
}



 
1;
