package EBox::Backup::OpticalDisc;
# module to get information about the disk inserted in the writer device
use strict;
use warnings;

use EBox::Sudo;
use EBox::Gettext;
use Readonly;
Readonly::Scalar my $DVD_MEDIA_INFO_PATH => '/usr/bin/dvd+rw-mediainfo';
Readonly::Scalar my $CDRECORD_PATH       => '/usr/bin/cdrecord';


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

  my @output = `$DVD_MEDIA_INFO_PATH $dev 2>&1`;

  if (grep { m/no media mounted/ }  @output) {
    
    return 'no_disc';
  }
  elsif (grep {m/non-DVD media mounted/} @output) {
    return undef;
  }

  my ($mountedMediaLine) = grep {m/Mounted Media:/} @output;
  if (!$mountedMediaLine) {
    throw EBox::Exceptions::External(__('Unable to recognize the mounted DVD media'));
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

  my $atipCmd = _cdrecordAtipCommands($dev);
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

sub _cdrecordAtipCommands
{
  my ($dev) = @_;
  return "$CDRECORD_PATH  -atip dev=$dev";
}

sub rootCommands
{
  my @commands = (
		  $CDRECORD_PATH,
		 );

  return @commands;
}
 
1;
