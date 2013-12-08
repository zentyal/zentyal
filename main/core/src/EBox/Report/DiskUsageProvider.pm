# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::Report::DiskUsageProvider;

# class: EBox::Report::DiskUsageProvider
#
#  Any module which wants add one or more section to the disk usage report must
#  subclass this module and override the _facilitiesForDiskUsage method.  Some
#  modules with special needs may want to override the diskUsage method instead
#  of _facilitiesForDiskUsage

# Method: diskUsage
#  return the different facilities which takes up disk space and the amount used
# in block size units
#
#  Named parameters:
#     blockSize - size of the block units (mandatory)
#     fileSystem - if present, we will only scan the supplied filesystem
#
#  Returns:
#
#   A reference to a hash which ocntains the used filesystem as keys
#   and a hash with the disk usage by facility or pseudo-facilty.
#     The facilities are named with his printable name
#
#  Bugs:
#    doesn't take account symbolic links
#    see _facilitiesForDiskUsage warnings
sub diskUsage
{
  my ($self, %params) = @_;
  my $blockSize = $params{blockSize};
  defined $blockSize or
    throw EBox::Exceptions::MissingArgument('blockSize');
  my ($fileSystemToScan) = $params{fileSystem};

  my %facilities = %{ $self->_facilitiesForDiskUsage() };

  my %moduleDiskUsage;

  while (my ($facility, $dirs_r) = each %facilities) {
    foreach my $dir (@{ $dirs_r }) {
      (-d $dir) or
          next;

      my $filesys = EBox::FileSystem::dirFileSystem($dir);
      if (defined $fileSystemToScan) {
        ($filesys eq $fileSystemToScan)
          or next;
      }

      $moduleDiskUsage{$filesys}->{$facility} += EBox::FileSystem::dirDiskUsage($dir, $blockSize);
    }

  }

  return \%moduleDiskUsage;
}

# Method: _facilitiesForDiskUsage
#
#   This method will be overriden by almost subclasses to notify which
#   facilities and directories need to be included in the report
#
# Returns:
#   A hash reference with the printable name of the facilities as keys
#    and a reference to the list of directories included in each facility
#
# Warning:
#   if the directories overlap some files will be counted twice
#   any directory specified shouldn't have a directory in another filesystem or
#   we will have a bad filesystem usage count
sub _facilitiesForDiskUsage
{
  return {};
}

1;
