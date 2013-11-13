# Copyright (C) 2008-2012 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package EBox::Report::RAID;

use strict;
use warnings;

use EBox;
use EBox::Sudo;

use File::Slurp qw(read_file);
use Error qw(:try);


use constant PROC_MDSTAT => '/proc/mdstat';
# see t/testdata fpr examples of mdstat files

# Group: Public functions

# Function: enabled
#
# Returns:
#
#    whethet the RAID is enabled in the system
#
# Warning:
#
#   it looks if /proc/mdstat exists
#
sub enabled
{
    my ($self, $raidInfo) = @_;
    defined $raidInfo or
        $raidInfo = info();

    my $nEntries = keys %{ $raidInfo };
    if ($nEntries > 1) {
        return 1;
    } elsif ($nEntries == 1) {
        if (exists $raidInfo->{unusedDevices}) {
            return @{ $raidInfo->{unusedDevices} } > 0;
        }
        return 1;
    } else {
        return 0;
    }
}

# Function: info
#
#  Retrieve the valuable info for RAID infrastructure if present.
#
#  Unfortunately, the /sys/block/md?/md directory doesn't exist so we will parse
#  PROC_MDSTAT to get the require information
#
# Returns:
#
#   hash reference with a key for each RAID array and a 'unusedDevices' entry
#
#   - the unusedDevices contains a list with the unused RAID devices
#   - each RAID array entry contains a hash reference with the following fields:
#
#        state - String the array state. Several values may appear
#                together separated by commas.
#                Possible values: 'active', 'degraded', 'recovering',
#                                 'resyncing', 'failed'.
#        type  - array type as found in mdstat (ej: raid1, raid2, ..)
#        activeDevicesNeeded - how many active RAID devices requires the  array
#                               to work properly
#        activeDevices      - how many active RAID devices are now
#        blocks             - size in blocks of the array
#        operation          - whether the array is engaged in some important
#                             management operation. Contains 'none' or
#                             the name of the operation.
#       operationPercentage - percentage of the operation completed so far.
#                             No present if there isn't any operation active
#       operationEstimatedTime - estimated time left for the operation's end.
#                             No present if there isn't any operation active
#       operationSpeed        - current operation speed, measured in data/time units.
#                             No present if there isn't any operation active
#       raidDevices        - reference to a hash with information of the devices
#                            which comprise the array.
#                            The RAID device numbers are used as keys and the
#                            values are a reference to a hash which the following
#                            fields:
#                                     device - device file of the RAID device
#                                     state  - state of the device.
#                                           Values: 'up', 'failure', 'spare'
# See also:
#      t/RAID.t to see some examples of the return value of this function
#
sub info
{
    my @mdstat = @{  _mdstatContents() };
    (@mdstat and (scalar @mdstat > 2)) or
        return undef;

    my %info;

    push @mdstat, 'endoffile:dummy'; # this dummy section is to force to process
                                     # the real last section
    my $currentSection;
    my @currentSectionData;

    foreach my $line (@mdstat) {
        chomp $line;
        $line =~ s/^\s*//;
        $line =~ s/\s*$//;
        next if $line =~ m/^\s*$/;

        my @parts =  split '\s*:\s*', $line, 2;
        if (@parts == 2 and $parts[0] ne 'bitmap') { # begins a new section
            my @sectionInfo = @{
                _processSection($currentSection, \@currentSectionData)
            };
            while (@sectionInfo) {
                my ($key, $value) = splice @sectionInfo, 0, 2;
                $info{$key} = $value;
            }

            # reset section variables to new section values
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
        _setArrayStatus($info{$dev});
    }

    return \%info;
}

# Group: Private methods

sub _mdstatContents
{
    if (not -r PROC_MDSTAT) {
        return [];
    }

    my $contents_r = read_file(PROC_MDSTAT, array_ref => 1);
    return $contents_r;
}

# calculate devices status using other fields values
sub _calculateDevicesStatus
{
    my ($info_r) = @_;

    my @statusArray = exists $info_r->{statusArray} ?
                                  @{ delete $info_r->{statusArray} } :
                                  ();
    my $activeDevicesNeeded = $info_r->{activeDevicesNeeded};
    my $raidDevices         = $info_r->{raidDevices};

    my $statusArrayPos = -1; # it has not to coincide with the nummbers bz it can
                            # be holes!
    my @devNumbers = sort keys  %{ $raidDevices };
    foreach my $number (@devNumbers) {
        $statusArrayPos += 1;
        my $devAttrs = $raidDevices->{$number};

        $devAttrs->{state} = '' unless (defined($devAttrs->{state}));
        if ($devAttrs->{state} eq 'failure') {
            if (not defined $statusArray[$statusArrayPos]) {
                $devAttrs = 'failure_spare';
            }
            next;
        } elsif ($devAttrs->{state} eq 'spare') {
            next;
        } elsif (not defined $activeDevicesNeeded or (not @statusArray)) {
            $devAttrs->{state} = 'up';  # XXX need more test..
        } else {
            my $status =  $statusArray[$statusArrayPos];
            if (not defined $status) {
                $devAttrs->{state} = 'spare';
            }  elsif ($status eq 'U') {
                $devAttrs->{state} = 'up';
            } elsif ($status eq '_') {
                $devAttrs->{state} = 'failure';
            } else {
                $devAttrs->{state} = 'spare';
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

# set the array state from the remainder elements
sub _setArrayStatus
{
    my ($info_r) = @_;

    my $state = '';
    if ( $info_r->{active} ) {
        $state .= 'active, ';
        if ( $info_r->{operation} ne 'none' ) {
            $state .= 'degraded, ';
        }
        if ( $info_r->{operation} eq 'recovery' ) {
            $state .= 'recovering';
        } elsif ( $info_r->{operation} eq 'resync' ) {
            $state .= 'resyncing';
        } elsif ( $info_r->{operation} eq 'reshape' ) {
            $state .= 'reshaping';
        } elsif ( $info_r->{operation} eq 'rebuild' ) {
            $state .= 'rebuilding';
        }
        if ( $info_r->{activeDevicesNeeded} > $info_r->{activeDevices} ) {
            unless ( $state =~ m/degraded/g ) {
                $state .= 'degraded';
            }
        }
    } else {
        $state .= 'failed';
    }
    $state =~ s/, $//g;
    $info_r->{state} = $state;
}

my %processBySection = ('Personalities'  => \&_processPersonalitiesSection,
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
                         $processBySection{$sectionName} :
                         \&_processDeviceSection;

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

    return [ unusedDevices => \@unusedDevices ];
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

    %deviceInfo = (%deviceInfo, _processDeviceArrayLine(shift @lines));

    foreach my $line (@lines) {
        my @newDeviceInfo;
        if ($line =~ m/^bitmap:/) {
            @newDeviceInfo = _processDeviceBitmapLine($line)
        } else {
            @newDeviceInfo = _processDeviceOperationLine($line);
       }
        %deviceInfo = (
            %deviceInfo,
            @newDeviceInfo,
           );

    }
    if (not $deviceInfo{operation}) {
        $deviceInfo{operation} = 'none';
    }


    return [$device => \%deviceInfo];
}

sub _processDeviceMainLine
{
    my ($line) = @_;
    my %deviceInfo;

    # Remove extra state info like "(read-only)" and "(auto-read-only)"
    $line =~ s/\s+\(\S*read-only\)//;

    my ($activeTag, $raidType, @raidDevicesTags) = split '\s', $line;

    $deviceInfo{active}= ($activeTag eq 'active') ? 1 : 0;
    $deviceInfo{type}= $raidType;

    my $raidDevices = _processRaidDevicesTags(@raidDevicesTags);
    $deviceInfo{raidDevices} = $raidDevices;

    return %deviceInfo;
}


sub _processDeviceArrayLine
{
    my ($line) = @_;

    my %deviceInfo;
    if ($line =~ m/(\d+)\sblocks\s+/) {
        $deviceInfo{blocks}= $1;
    }
    if ($line =~ m/\s([^\s]+?)\s+chunk/) {
        $deviceInfo{chunkSize}= $1;
    }

    if ($line =~ m{\s\[(\d+)/(\d+)\]\s+\[(.*?)\]}) {
        # $4, $5 the number of active devices needed and the number of active
        $deviceInfo{activeDevicesNeeded}= $1;
        $deviceInfo{activeDevices}=  $2;
        $deviceInfo{statusArray}= [ split //, $3  ];

    }

    if ($line =~ m{\salgorithm\s+(.*?)\s}) {
        $deviceInfo{algorithm} = $1;
    }

    if (not keys %deviceInfo) {
        EBox::debug("not match for device array line regexes: $line");
    }

    return %deviceInfo;
}

sub _processDeviceOperationLine
{
    my ($line) = @_;

    $line = '' unless (defined($line));
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
            (\(\w\))?  # $3 state mark (optional)
    }x;

    foreach my $tag (@tags) {
        my $raidDevice;
        my $device;
        my $stateMark;
        my $failure = 0;
        my $spare  = 0;

        if ($tag =~ m/$devTagRe/) {
            $device = $1;
            $raidDevice =$2;
            $stateMark = $3;

            if (not $device =~ m{/}) {
                # if it is 'relative' device we may infer that it is in the /dev dir
                $device = '/dev/' . $device;
            }
        }
        else {
            EBox::error("Cannot extract device from tag $tag. Skipping tag");
            next;
        }

        $devices{$raidDevice} = {
            device  => $device,
        };

        if ($stateMark) {
            if ($stateMark eq '(F)') {
                $devices{$raidDevice}->{state} = 'failure';
            } elsif ($stateMark eq '(S)') {
                $devices{$raidDevice}->{state} = 'spare';
            }

        }
    }

    return (raidDevices => \%devices);
}


sub _processDeviceBitmapLine
{
    my ($line) = @_;
    my ($title, $data) = split '\s*:\s*', $line, 2;
    return (bitmap => $data);
}

1;
