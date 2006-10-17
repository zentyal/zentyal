package EBox::Backup::OpticalDisc;
# module to get information about the disk inserted in the writer device
use strict;
use warnings;

use Error qw(:try);
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

# return hash with:
#   media: media name or 'no_disc' if device is empty. 
#   writable              if disc is writable (not full)
#  may throw exception upon error
# XXX: TODO discriminate between closed and appendable discs
sub media
{
  my ($dev) = @_;
  defined  $dev or throw EBox::Exceptions::Internal("device parameter not found");

  my $info;
  $info = infoFromDvdMediaInfo($dev);
  
  defined $info or $info = infoFromCdrdao($dev) ;

  return  $info;

}


sub infoFromDvdMediaInfo
{
  my ($dev) = @_;

  my @output =  @{ EBox::Sudo::rootWithoutException("$EBox::Backup::RootCommands::DVDMEDIAINFO_PATH $dev 2>&1")};

  if (grep { m/no media mounted/ }  @output) {
    return  {media => 'no_disc', writable => 0};
  }
  elsif (grep {m/non-DVD media mounted/} @output) {
    return undef;
  }

  my ($media, $writable);
  try {
    my $parseResults_r = _parseOutput(\@output, 'Mounted Media', 'Disc status');
    defined $parseResults_r or throw EBox::Exceptions::Internal();
 
    if ($parseResults_r->{'Mounted Media'} =~ m/(DVD.*?)(\s|$)/) {
      $media = $1;
    }
    $writable = $parseResults_r->{'Disc status'} eq 'blank' ? 1 : 0;

    if ((!defined $media) or (!defined $writable)) {
      throw EBox::Exceptions::Internal();
    } 
  }
  otherwise {
    EBox::error("Error in infoFromDvdMediaInfo.\n media: $media writable: $writable: \ndvd+rw-mediainfo output:\n @output" );
    throw EBox::Exceptions::External(__('Unable to recognize the mounted DVD media'));
  };

  return {media => $media, writable => $writable};
}


sub infoFromCdrdao
{
  my ($dev) = @_;

  my $diskInfoCmd = "$EBox::Backup::RootCommands::CDRDAO_PATH disk-info --device $dev";
  my @output = @{ EBox::Sudo::rootWithoutException($diskInfoCmd) };

  if (grep { m/Unit not ready/ } @output) {
    return  {media => 'no_disc', writable => 0};
  }

  my $parseResults_r = _parseOutput(\@output, 'CD-RW', 'CD-R empty');
  if (!defined $parseResults_r) {
    EBox::error("Error in infoFromCdrdao. \ncdrdao command: $diskInfoCmd \ncrdao output:\n @output" );
    throw EBox::Exceptions::External(__('Unable to recognize the mounted CD media'));
  } 

  my ($media, $writable);
  $media = $parseResults_r->{'CD-RW'} eq 'yes'? 'CD-RW' : 'CD-R';
  $writable = $parseResults_r->{'CD-R empty'} eq 'yes'? 1 : 0;
  
  return {media =>$media, writable => $writable};
}

sub _parseOutput
{
  my ($output_r, @labels) = @_;
  my @output = @{ $output_r };

  my %results;
  foreach my $label (@labels) {
    my ($lineFound) = grep {m/\s*$label\s*:/ } @output;
    $lineFound or return undef;
    chomp $lineFound;

    my ($labelAgain, $value) = split '\s*:\s*', $lineFound;
    defined $value or return undef;
    $results{$label} = $value;
  }

  return \%results;
}

 
1;
