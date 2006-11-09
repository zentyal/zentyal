package EBox::Backup::OpticalDisc;
# module to get information about the disk inserted in the writer device
use strict;
use warnings;

use Error qw(:try);
use EBox::Sudo;
use EBox::Gettext;
use EBox::Backup::RootCommands;
use Params::Validate;

use Readonly;
Readonly::Scalar my $CD_SIZE   => 681000000; # we assume 650Mb instead 700 to err in the safe side
Readonly::Scalar my $DVD_SIZE  => 4380000000; # likewise we assume 4.38 GiB


#
# Function: sizeForMedia
#
#   	This function returns the maximum capacity of a media of this type. Now we can write on empty discs so this wil be return the space availble on the disc	
#
# Parameters:
#
#    media - media type. (CD-R, CD-RW, DVD-R or DVD-RW)
#
# Returns:
#	
#   the maximum capacity of a media of this type
# 
# Exceptions:
#   
#        Internal - unknow media type
#
sub sizeForMedia
{
  my ($media) = @_;
  validate_pos(@_, 1);

  return $CD_SIZE  if ($media eq 'CD-R')  or ($media eq 'CD-RW');
  return $DVD_SIZE if ($media eq 'DVD-R') or ($media eq 'DVD-RW');
  
  throw EBox::Exceptions::Internal("Incorrect media or size data unknown: $media");
}


#
# Function: media
#
#  Parameters:
#
#   dev - device file of the CD/DVD writer drive
#
#  Returns:
#     hash with the following fields:
#     media     - media name or 'no_disc' if device is empty. 
#    writable  - if disc is writable (not full)
#
# todo:
#  discriminate between closed and appendable discs
sub media
{
  my ($dev) = @_;
  validate_pos(@_, 1);

  my $info;
  $info = _infoFromDvdMediaInfo($dev);
  
  defined $info or $info = _infoFromCdrdao($dev) ;

  return  $info;

}

#
# Function: infoFromDvdMediaInfo
#
#   Used internally by media to get information about possible dvd disks		
#
# Parameters:
#
#  dev - the device file of the DVD writer drive
#
sub _infoFromDvdMediaInfo
{
  my ($dev) = @_;

  EBox::Backup::RootCommands::checkExecutable($EBox::Backup::RootCommands::DVDMEDIAINFO_PATH, 'dvd+rw tools');

  my @output;
  try {
    @output =  @{ EBox::Sudo::root("$EBox::Backup::RootCommands::DVDMEDIAINFO_PATH $dev")};
  }
 catch EBox::Exceptions::Sudo::Command with {
   my $ex = shift;
   @output = @{ $ex->output };
   push @output, @{ $ex->error };
 };


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

#
# Function: infoFromCdrdap
#
#   Used internally by media to get information about possible CD-ROM disks		
#
# Parameters:
#
#  dev - the device file of the CD-ROM writer drive
#
sub _infoFromCdrdao
{
  my ($dev) = @_;

  EBox::Backup::RootCommands::checkExecutable($EBox::Backup::RootCommands::CDRDAO_PATH, 'cdrdao');

  my $diskInfoCmd = "$EBox::Backup::RootCommands::CDRDAO_PATH disk-info --device $dev";
  my @output;
  try {
    @output =  @{ EBox::Sudo::root($diskInfoCmd)};
  }
 catch EBox::Exceptions::Sudo::Command with {
   my $ex = shift;
   @output = @{ $ex->output };
   push @output, @{ $ex->error };
 };

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
