package EBox::Report::RAID;
#
use strict;
use warnings;

use EBox;
use EBox::Sudo;

use File::Slurp qw(read_file);
use Error qw(:try);


use constant PROC_MDSTAT => '/proc/mdstat';
# see t/testdata fpr examples of mdstat files


# Function: enabled
# Returns:
#  wethet the RAID is enabled in the system
# Warning:
#   it looks if /proc/mdstat exist
sub enabled
{
  return (-r PROC_MDSTAT)
}


#  Unfortunely the /sys/block/md?/md directory doesn't exist so we will parse
#  PROC_MDSTAT  to get the info
#
# Returns: hash reference with a key for each RAID array and a 'unusedDevices' entry
#
#   -  the unuseDevices contains a list with the unused RAI devices 
#   - each RAID array entry contains a hash reference with the following fields:
#        active - wether the array is active 
#         type  - array type as found in mdstat (ej: raid1, raid2, ..)
#        activeDevicesNeeded - how many active RAID devices requires the  array
#                               to function properly
#        activeDevices      - how may active RAID devices are now
#        blocks             - size in blocks of the array
#        operation          - wether the array is engaged in some important
#                             management operation. Contains 'none' or 
#                             the name of the operation.
#       operationPercentage - percentage of the operation completed so far.
#                             No present if there isn't any operation active
#       operationEstimatedTime - estimated time left for the operation's end
#                             No present if there isn't any operation active
#       operationSpeed        - current speed of the operation, measured in 
#                               data/time units   
#                             No present if there isn't any operation active
#       raidDevices        - reference to a hash with information of the devices
#                            which forms the array.
#                            The RAID device numbers are used as keys and the 
#                            values are a reference to a hash which the following
#                            fields:
#                                     device - device file of the RAID device
#                                     state  - state of the device.
#                                           Values: 'up', 'failure', 'spare'
# See also:
#      t/RAID.t to see some examples of the return value of this function
sub info
{
  my @mdstat = @{  _mdstatContents() };
  @mdstat or
    return undef;

  my %info;

  push @mdstat, 'endoffile:dummy'; # this dummy section is to forrce to process
                                   # the real last section
  my $currentSection;
  my @currentSectionData;
  foreach my $line (@mdstat) {
    chomp $line;
    $line =~ s/^\s*//;
    $line =~ s/\s*$//;
    next if $line =~ m/^\s*$/;


    my @parts =  split '\s*:\s*', $line, 2;
    if (@parts == 2) { # begins a new section
      my @sectionInfo = @{ _processSection($currentSection, \@currentSectionData)};
      while (@sectionInfo) {
	my ($key, $value) = splice @sectionInfo, 0, 2;
	$info{$key} = $value;
      }
      
      # reset section variables to new section vlaues
      my ($sectionHeader, $sectionData) = @parts;
      $currentSection = $sectionHeader;
      @currentSectionData = ($sectionData);
      
    }
    else {
      push @currentSectionData, $line;
    }

  }
  

  foreach my $dev (keys %info) {
    if (not $dev =~ m{^/dev/}) {
      # not a device entry. Next
      next;
    }

    _calculateDevicesStatus($info{$dev});
    
  }


  return \%info;
}



sub _mdstatContents
{
  enabled()
    or return [];

  my $contents_r = read_file(PROC_MDSTAT, array_ref => 1);
  return $contents_r;
}

# calcualte devices status using other fields values
sub _calculateDevicesStatus
{
  my ($info_r) = @_;

  my @statusArray         =  exists $info_r->{statusArray} ?
                                  @{ delete $info_r->{statusArray} } : () ;
  my $activeDevicesNeeded = $info_r->{activeDevicesNeeded};
  my $raidDevices         = $info_r->{raidDevices};

  my @devNumbers = sort keys  %{ $raidDevices };
  foreach my $number (@devNumbers) {
    my $devAttrs = $raidDevices->{$number};
    
    my $spare = 0;
    my $up    = 0;

    if ($devAttrs->{state} eq 'failure') {
      next;
    }
    elsif (not defined $activeDevicesNeeded or (not @statusArray)) {
      $devAttrs->{state} = 'up';  # XXX need more test..
    }
    elsif (($number >= $activeDevicesNeeded)  ) {
	$devAttrs->{state} = 'spare';
    }
    else {
      my $status =  $statusArray[$number];
      defined $status or
	EBox::warn("Undefined array status item for raid device $number");

      if ($status eq 'U') {
	$devAttrs->{state} = 'up';
      }
    }

  }


  # if we lack activeDevices and activeDevicesNeeded calcualte form the number
  # of devices
  if (not (exists $info_r->{activeDevicesNeeded}) ) {
        $info_r->{activeDevicesNeeded} =  @devNumbers;
  }
  if (not (exists $info_r->{activeDevices}) ) {
    $info_r->{activeDevices} = grep {
                    $raidDevices->{$_}->{state} eq 'up'
		  } @devNumbers;
  }


}

my %processBySection = (
			'Personalities' => \&_processPersonalitiesSection,
			'unused devices' => \&_processUnusedDevicesSection,
		       );

sub _processSection
{
  my ($sectionName, $sectionLines_r) = @_;

  defined $sectionName or
    return [];

  my @sectionLines = @{ $sectionLines_r };

  my @sectionInfo; # contains the pairs of keys and values which will be
                   # returned 

  my $sectionSub;
  $sectionSub = exists $processBySection{$sectionName}  ?
                                          $processBySection{$sectionName}
                                          : \&_processDeviceSection;

  

  return $sectionSub->(@_);

}

sub _processPersonalitiesSection
{
  my ($sectionName, $sectionLines_r) = @_;
  # for now we ignore this section
  return [];
}


sub _processUnusedDevicesSection
{
  my ($sectionName, $sectionLines_r) = @_;

  my @sectionLines = @{ $sectionLines_r };
  my $unusedDevicesLine = join ' ', @sectionLines;

  my @unusedDevices = split '\s', $unusedDevicesLine;
  if ($unusedDevices[0] eq '<none>') {
    @unusedDevices = (); # none means none
  }
  

  return [
	  unusedDevices => \@unusedDevices
	 ];

}



sub _processDeviceSection
{
  my ($device, $deviceLines_r) = @_;
  $device = '/dev/' . $device;

  my @lines = @{ $deviceLines_r };

  my %deviceInfo; # hash  with all the parsed information

  %deviceInfo = (
		 %deviceInfo,
		_processDeviceMainLine(shift @lines)
	       );
 

  my $processDeviceArrayLineSub = __PACKAGE__->can('_processDeviceArrayLineOfType' . ucfirst $deviceInfo{type});
  if ($processDeviceArrayLineSub) {
  %deviceInfo = (
		 %deviceInfo,
		 $processDeviceArrayLineSub->(shift @lines),
		);
  }
  else {
    EBox::debug('no _processDeciveArrayLineOfType method for type ' . $deviceInfo{type});
    shift @lines;
  }

  %deviceInfo = (
		 %deviceInfo,
		 _processDeviceOperationLine(shift @lines),
		);


 
  
  return [$device => \%deviceInfo];
}




sub _processDeviceMainLine
{
  my ($line) = @_;
  my %deviceInfo;


  my ($activeTag, $raidType, @raidDevicesTags) = split '\s', $line;
  
  $deviceInfo{active}= ($activeTag eq 'active') ? 1 : 0;
  $deviceInfo{type}= $raidType;

  my $raidDevices = _processRaidDevicesTags(@raidDevicesTags);
  $deviceInfo{raidDevices} = $raidDevices;

  return %deviceInfo;
}


sub _processDeviceArrayLineOfTypeRaid0
{
  my ($line) = @_;
  my %deviceInfo;
  my $lineRe = qr{
    ^(\d+)\sblocks\s+  # $1 blocks count
    (.*?)\s+chunks     # $2 chunkSize
  }x;

  if ($line =~ m/$lineRe/) {
    $deviceInfo{blocks}= $1;
    $deviceInfo{chunkSize} = $2;
  }
  else {
    EBox::debug("not match for RAID0 regex: $line");
   }

  return %deviceInfo;
}

sub _processDeviceArrayLineOfTypeRaid1
{
  my ($line) = @_;

  my %deviceInfo;

  my $lineRe =  qr{
    ^(\d+)\sblocks\s+  # $1 blocks size
    \[(\d+)/(\d+)\]\s+ # $2, $3 the number of active devices needed
                       # and the number of active devices
    \[(.*?)\]          # $4 status array ej: [UU]
  }x;


  if ($line =~ m/$lineRe/ ) {
    $deviceInfo{blocks}= $1;
    $deviceInfo{activeDevicesNeeded}= $2;
    $deviceInfo{activeDevices}=  $3;
    $deviceInfo{statusArray}= [ split //, $4  ];
   }  
  else {
    EBox::debug("not match for RAID1 regex: $line");
   }

  return %deviceInfo;
}


sub _processDeviceArrayLineOfTypeRaid5
{
  my ($line) = @_;

  my %deviceInfo;

  my $lineRe =  qr{
    ^(\d+)\sblocks\s+  # $1 blocks size
    level\s+\d+,\s+    # ignored level line
    (.*?)\s+chunk,\s+  # $2 chunk size
    algorithm\s+(.*?)\s # $3 algorithm
    \[(\d+)/(\d+)\]\s+ # $4, $5 the number of active devices needed
                       # and the number of active devices
    \[(.*?)\]          # $6 status array ej: [UU]
  }x;


  if ($line =~ m/$lineRe/ ) {
    $deviceInfo{blocks}= $1;
    $deviceInfo{chunkSize} = $2;
    $deviceInfo{algorithm} = $3;
    $deviceInfo{activeDevicesNeeded}= $4;
    $deviceInfo{activeDevices}=  $5;
    $deviceInfo{statusArray}= [ split //, $6  ];
   }  
  else {
    EBox::debug("not match for RAID5 regex: $line");
   }

  return %deviceInfo;
}



sub _processDeviceOperationLine
{
  my ($line) = @_;

  my %deviceInfo;

  my $operationLineRe =  qr{
         (\w+)\s*            # $1 operation name
         =\s*(\d+\.?\d*)%\s+ # $2 percentaje complete. may use one or two digits
         .*?                 # ignored blocks comleted field
         finish=(.*?)\s+     # $3 estimated relative finish time
         speed=(.*?)         # $4 operation speed
        (\s|$)               # end of parsing
  }x;


  my $operation = 'none';
  if ($line =~ m/$operationLineRe/) {
    $operation  = $1;
    $deviceInfo{'operationPercentage'}= $2;
    $deviceInfo{'operationEstimatedTime'}= $3;
    $deviceInfo{'operationSpeed'}= $4;
  }


  $deviceInfo{operation} = $operation;

  return %deviceInfo;
}


sub _processRaidDevicesTags
{
  my (@tags) = @_;
  my %devices;


  my $devTagRe = qr{
       ^(.*?)     # $1 device filename
       \[(\d)\]   # $2 device RAID number
  }x;

  foreach my $tag (@tags) {
    my $raidDevice;
    my $device;
    my $failure = 0;

    if ($tag =~ m/$devTagRe/) {
      $device = $1;
      $raidDevice =$2;

      if (not $device =~ m{/}) { 
          # if it is 'relative' device we may infer that it is in the /dev dir
          $device = '/dev/' . $device;
      }   
      
    }
    else {
      EBox::error("Cannot extract device from tag $tag. Skipping tag");
      next;
    }


    if ($tag =~ m/\(F\)/) {
      $failure = 1;
    }


    $devices{$raidDevice} = {
			     device  => $device,
			    };

    if ($failure) {
        $devices{$raidDevice}->{state} = 'failure';
     }

  }
  
  return (raidDevices => \%devices);
}







1;
