package EBox::Report::DiskUsage;
#
use strict;
use warnings;

use EBox::Gettext;
use EBox::CGI::Temp;
use EBox::Backup;
use EBox::FileSystem;

use Chart::Pie;
use GD;
use Filesys::Df;
use Perl6::Junction qw(all);


use constant PERCENTAGE_TO_APPEAR => 0.1; # percentage of disk size must reach a
                                          # facilty to be worthwile of display
                                          # in the chart

use constant PIE_RADIUS => 50;

use constant MIN_GRAPH_HEIGHT => 400;
use constant MIN_GRAPH_WIDTH  => 650;

# Function: charts
#
#   make a disk usage chart formatted as a pie chart for each file system
#
# Returns: a hash ref with the file system as key and the url needed to embed
# the chart in a web page as value
sub charts
{
  my %charts;
  my %usageData = %{ usage() };

  while (my ($fsys, $usage) = each %usageData) {
    my $datasets   = _chartDatasets($usage);
    $charts{$fsys} =_chart($datasets);
  }

  return \%charts;
}

# Function: chart
#
#   make a disk usage chart formatted as a pie chart for the specified partition
#
#  Parametes:
#     partition - path to the partition device file
#
# Returns: 
#  the url needed to embed the chart in a web page as value
sub chart
{
  my ($partition) = @_;
  my $usage = usage( fileSystem => $partition);

  exists $usage->{$partition} or
    throw EBox::Exceptions::External(
      __x('No usage data for {d}. Are you sure is a valid disk?', d => $partition)
    );

  my $datasets = _chartDatasets($usage->{$partition});
  return _chart($datasets);
}


sub _chart
{
  my ($datasets) = @_;

  my $imageLocation = EBox::CGI::Temp::newImage();
 
  my $labelFont  = GD::Font->Large;
  my $legendFont = GD::Font->Small;
  my $textSpace  = 2;
 
  my %colors = (
                dataset0 => [18, 130, 76],
               );

  my $chartParams = {
                     transparent => 'true',
                     grey_background => 'false',
                     
                     precision       => 2,
                     
                     legend          => 'bottom',
                     colors => \%colors,
                     label_font => $labelFont,
                     legend_font => $legendFont,
                     text_space  => $textSpace,
                    };


  my $chart = new Chart::Pie( _calcGraphSize($datasets, $chartParams)  );



  $chart->set (
               %{ $chartParams  }
            );

  foreach my $ds_r (@{ $datasets }) {
    $chart->add_dataset(  @{ $ds_r  });
  }


  $chart->png($imageLocation->{file});


  return $imageLocation->{url};
}

# the calcualtion is derivated of the one found in Graph::Pie::_draw_data
# this assumes that we use percents to show the values in the pie chart
#  and that the legend is at the bottom
sub _calcGraphSize
{
  my ($datasets, $params) = @_;
  my $graphWidth = 1;
  my $graphHeight = 1;

  $params->{'legend_space'} = 4; # extracted from Chart::Base::_init

  my $max_label_len = 1;

  my %labelsByUsage = @{ $datasets };

  while (my($label, $value) = each %labelsByUsage) {
    my $text =  sprintf("%s %4.2f%%", $label, $value );
    my $length = length $text;
    if ($length > $max_label_len) {
      $max_label_len = $length;
    }
  }


  my $fWidth = $params->{label_font}->width;
  my $fHeight = $params->{label_font}->height;

  $max_label_len *= $fWidth;
  
  my $labeldistance = 2*($fWidth > $fHeight ? $fWidth : $fHeight);
  my $pieLabelsSize =    2*$max_label_len + $labeldistance;

  # graph width
  $graphWidth = $pieLabelsSize + PIE_RADIUS;
  
  $graphWidth += $params->{text_space} *2;

  if ($graphWidth < MIN_GRAPH_WIDTH) {
    $graphWidth = MIN_GRAPH_WIDTH;
  }


  # graph height
  $graphHeight= $pieLabelsSize + PIE_RADIUS;
  # calculate the height used by the legend and add it to the height



  # we take a row for datapoint to simplify to don't have to follow all the
  # calculations scattered in Chart code
  my $rows = values %labelsByUsage;
  my $legend_row_height = $params->{legend_font}->height + $params->{text_space};

  $graphHeight += ($rows * $legend_row_height) + $params->{text_space}
                              + (2 * $params->{'legend_space'});

  if ($graphHeight < MIN_GRAPH_HEIGHT) {
    $graphHeight = MIN_GRAPH_HEIGHT;
  }

  return ($graphWidth, $graphHeight);
}


#  Function: usage
#
#  get a disk usage report by facility. The pseudo-facilities 'free' and
#  'system' are also present, the first one to show the amount of free disk
#  space and the second one the amount of disk taken up to the files which
#  aren't included in any facility
#
#  Parameters:
#
#     fileSystem - if this parameter is supplied, it only scan the supplied
#     file system. Only disk and non-media filesystems are accepted.
#
# Returns: 
#    reference to a hash with the filesystem  as keys
#    and a hash with the disk usage in blocks by facility or pseudo-facility  as
#    value. Block's size unit is 1Mb
#
sub usage
{
  my (%params) = @_;

  my $blockSize = 1048576; # 1 Mb block size
  my $fileSystemToScan = $params{fileSystem};

  my $fileSystems = partitionsFileSystems();

  # check fileSystem argument if present
  if (defined $fileSystemToScan ) {
    if ($fileSystemToScan ne all keys %{ $fileSystems }) {
      throw EBox::Exceptions::External(
        __x('Invalid file system: {f}. Only regular and no removable media file systems are accepted',
            f => $fileSystemToScan
           )
                                      );
    }
  }

  # initialize partitions to zero usage
  my %usageByFilesys = map {
    $_ => { facilitiesUsage => 0, }
  } keys %{ $fileSystems };


  # get usage infromation from modules
  my @modUsageParams = ( blockSize => $blockSize, );
  if (defined $fileSystemToScan) {
    push @modUsageParams, ( fileSystems => $fileSystemToScan);
  }  

  my $global = EBox::Global->getInstance();
  foreach my $mod (@{ $global->modInstancesOfType('EBox::Report::DiskUsageProvider' )}) {
    my $modUsage = $mod->diskUsage( @modUsageParams );

    while (my ($filesys, $usage) = each %{ $modUsage }) {
      while (my ($facility, $blocks) = each %{ $usage }) {
        $usageByFilesys{$filesys}->{facilitiesUsage} += $blocks;
        $usageByFilesys{$filesys}->{$facility}       += $blocks;
      }
    }
    
  }

 
  # calcualte system usage and free space for each file system
  foreach my $fileSys (keys %usageByFilesys) {
    exists $fileSystems->{$fileSys} or
      throw EBox::Exceptions::Internal("File system not found: $fileSys");

    my $mountPoint = $fileSystems->{$fileSys}->{mountPoint};

    my $df = df($mountPoint, $blockSize ); 

    my $facilitiesUsage = delete $usageByFilesys{$fileSys}->{facilitiesUsage};
    my $totalUsage      = sprintf ("%.2f", $df->{used});
    my $systemUsage     = $totalUsage - $facilitiesUsage;
    my $freeSpace       = sprintf ("%.2f", $df->{bfree});
    
    $usageByFilesys{$fileSys}->{system} = $systemUsage;
    $usageByFilesys{$fileSys}->{free}   = $freeSpace;
  }
                   


  return \%usageByFilesys;
}


#  Function: partitionsFileSystems
#
#   return the file system data for mounted disk partitions
#
# Returns: 
#      a hash reference with the file system as key and a hash with his
#      properties as value.
#      The properties are: mountPoint, type, options, dump and pass
#      The properties have the same format that the fields in the fstab file
#
sub partitionsFileSystems
{
  my %fileSys = %{  EBox::FileSystem::fileSystems() };

  foreach my $fs (keys %fileSys) {
    # remove not-device filesystems
    if (not $fs =~ m{^/dev/}) {
      delete $fileSys{$fs};
      next;
    } 

  # remove removable media files
    my $mpoint = $fileSys{$fs}->{mountPoint};
    if ($mpoint =~ m{^/media/}) {
      delete $fileSys{$fs};
      next;
    }

  }

  return \%fileSys;
}


sub _chartDatasets
{
  my ($usageByFacility_r) = @_;
  my %usageByFacility = %{  $usageByFacility_r };

  my @labels;
  my @diskUsage;

  # we calculate the minimal size needed to appear in the chart
  my $totalSpace = 0;
  $totalSpace += $_ foreach values %usageByFacility;
  my $minSizeToAppear = ($totalSpace * PERCENTAGE_TO_APPEAR) / 100;


  my $freeSpace   = delete $usageByFacility{free};
  my $systemUsage = delete $usageByFacility{system};

  # we put free space and system usage first bz we want they have always the
  # same colors
  push @labels, __('Free space');
  push @diskUsage, $freeSpace . ' Mb';

  push @labels,     __('System');
  push @diskUsage, $systemUsage . ' Mb';

  while (my ($facilityName, $facilityUsage) = each %usageByFacility ) {
    ($facilityUsage >= $minSizeToAppear) or
      next;

    push @labels, $facilityName;
    push @diskUsage, $facilityUsage . ' Mb';
  }

  return [
          \@labels,
          \@diskUsage,
         ];
}





1;
