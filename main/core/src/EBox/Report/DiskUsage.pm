# Copyright (C) 2008-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::Report::DiskUsage;

use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
 use EBox::Backup;
 use EBox::FileSystem;

 use Filesys::Df;
 use Perl6::Junction qw(all);

 use constant PERCENTAGE_TO_APPEAR => 0.1; # percentage of disk size must reach a
                                           # facilty to be worthwile of display
                                           # in the chart

 sub fsDataset
 {
     my ($partition) = @_;
     my $usage = usage( fileSystem => $partition);

     exists $usage->{$partition} or
         throw EBox::Exceptions::External(
             __x('No usage data for {d}. Are you sure is a valid disk?', d => $partition)
            );

     my $datasets = _chartDatasets($usage->{$partition});
     return $datasets;
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
 #    value. Block's size unit is 1MB
 #
 sub usage
 {
   my (%params) = @_;

   my $blockSize = 1048576; # 1 MB block size
   my $fileSystemToScan = $params{fileSystem};

   my $fileSystems = EBox::FileSystem::partitionsFileSystems();

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

   # calculate system usage and free space for each file system
   foreach my $fileSys (keys %usageByFilesys) {
     exists $fileSystems->{$fileSys} or
       throw EBox::Exceptions::Internal("File system not found: $fileSys");

     my $mountPoint = $fileSystems->{$fileSys}->{mountPoint};

     my $df = df($mountPoint, 1 );

     my $facilitiesUsage = delete $usageByFilesys{$fileSys}->{facilitiesUsage};
     my $totalUsage       = $df->{used} / $blockSize;
     my $systemUsage     = $totalUsage - $facilitiesUsage;
     if ($systemUsage < 0) {
         if ($systemUsage > -1000) {
             # small round error, approximate to zero
             $systemUsage = 0;
         } else {
             EBox::error(
 "Error calculating system usage. Result: $systemUsage. Set to zero for avoid error"
                        );
             $systemUsage = 0;
         }

     }

     my $freeSpace = $df->{bfree} / $blockSize;

     $usageByFilesys{$fileSys}->{system} = $systemUsage;
     $usageByFilesys{$fileSys}->{free}   = $freeSpace;
   }

   return \%usageByFilesys;
 }

 sub _chartDatasets
 {
   my ($usageByFacility_r) = @_;
   my %usageByFacility = %{  $usageByFacility_r };

   my %labels;
   my @data;
   my %dataByLabel;

   # we calculate the minimal size needed to appear in the chart
   my $totalSpace = 0;
   $totalSpace += $_ foreach values %usageByFacility;
   my $minSizeToAppear = ($totalSpace * PERCENTAGE_TO_APPEAR) / 100;

   my $freeSpace   = delete $usageByFacility{free};
   my $systemUsage = delete $usageByFacility{system};

   # we put free space and system usage first bz we want they have always the
   # same colors

   # choose correct unit
   my $unit = 'MB';
   if ($freeSpace > 1024 or $systemUsage > 1024) {
       $unit = 'GB';
   } else {
       foreach my $size (values %usageByFacility) {
           if ($size > 1024) {
               $unit = 'GB';
               last;
           }
       }
   }

   my $freeSpaceLabel = __('Free space');
   push @data, {label => $freeSpaceLabel, data => _sizeForUnit($freeSpace, $unit)};
   $labels{$freeSpaceLabel} = _sizeLabelWithUnit($freeSpace, $unit);

   my $systemLabel = __('System');
   push @data, {label => $systemLabel, data => _sizeForUnit($systemUsage, $unit)};
   $labels{$systemLabel} = _sizeLabelWithUnit($systemUsage, $unit);


   while (my ($facilityName, $facilityUsage) = each %usageByFacility ) {
       ($facilityUsage >= $minSizeToAppear) or
           next;

       push @data, {label => $facilityName, data => _sizeForUnit($facilityUsage, $unit)};
       $labels{$facilityName} = _sizeLabelWithUnit($facilityUsage, $unit);
   }

  return {
          data   => \@data,
          usageByLabel => \%labels,
         };
}

sub _sizeForUnit
{
    my ($size, $unit) = @_;

    if ($unit eq 'GB') {
        return $size / 1024;
    } elsif ($unit eq 'MB') {
        return $size;
    } else {
        throw EBox::Exceptions::Internal("Unknown unit: $unit");
    }
}

sub _sizeLabelWithUnit
{
    my ($size, $unit) = @_;

    if ($unit eq 'GB') {
        return sprintf ('%.2f GB', $size / 1024);
    } elsif ($unit eq 'MB') {
        return sprintf ('%.2f MB', $size);
    } else {
        throw EBox::Exceptions::Internal("Unknown unit: $unit");
    }
}

1;
