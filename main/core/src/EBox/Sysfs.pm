# Copyright (C) 2010-2013 Zentyal S.L.
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

package EBox::Sysfs;

use base 'Exporter';

our @EXPORT_OK = qw(read_value);

# Function: read_value
#
#      Reads a value from a sysfs file
#
# Parameters:
#
#      sysfs_path - Path to sysfs file
#
# Returns:
#
#      A string with the first line of the sysfs file

sub read_value # (sysfs_path)
{
    my ($sysfs_path) = @_;
    open(my $sysfs_file, '<', $sysfs_path);
    my $value = <$sysfs_file>;
    close($sysfs_file);
    $value =~ s/\s+$//;
    return $value;
}
