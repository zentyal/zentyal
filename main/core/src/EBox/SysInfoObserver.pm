# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::SysInfoObserver;

use strict;
use warnings;

use EBox::Gettext;

sub new
{
	my $class = shift;
	my $self = {};
	bless ($self, $class);
	return $self;
}

# Method: hostNameChanged
#
# Parameters:
#
#   oldHostName
#   newHostName
#
sub hostNameChanged
{
    my ($self, $oldHostName, $newHostName) = @_;

    return undef;
}

# Method: hostNameChangedDone
#
# Parameters:
#
#   oldHostName
#   newHostName
#
sub hostNameChangedDone
{
    my ($self, $oldHostName, $newHostName) = @_;

    return undef;
}

# Method: hostDomainChanged
#
# Parameters:
#
#   oldDomainName
#   newDomainName
#
sub hostDomainChanged
{
    my ($self, $oldDomainName, $newDomainName) = @_;

    return undef;
}

# Method: hostDomainChangedDone
#
# Parameters:
#
#   oldDomainName
#   newDomainName
#
sub hostDomainChangedDone
{
    my ($self, $oldDomainName, $newDomainName) = @_;

    return undef;
}

1;
