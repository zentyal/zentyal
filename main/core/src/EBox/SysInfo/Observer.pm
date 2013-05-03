# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::SysInfo::Observer;

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
#   Invoked before the change takes place. Any module implementing this
#   method can abort the change throwing an exception.
#
# Parameters:
#
#   oldHostName
#   newHostName
#
sub hostNameChanged
{
    my ($self, $oldHostName, $newHostName) = @_;
}

# Method: hostNameChangedDone
#
#   Invoked after the change takes place
#
# Parameters:
#
#   oldHostName
#   newHostName
#
sub hostNameChangedDone
{
    my ($self, $oldHostName, $newHostName) = @_;
}

# Method: hostDomainChanged
#
#   Invoked before the change takes place. Any module implementing this
#   method can abort the change throwing an exception.
#
# Parameters:
#
#   oldDomainName
#   newDomainName
#
sub hostDomainChanged
{
    my ($self, $oldDomainName, $newDomainName) = @_;
}

# Method: hostDomainChangedDone
#
#   Invoked after the change takes place
#
# Parameters:
#
#   oldDomainName
#   newDomainName
#
sub hostDomainChangedDone
{
    my ($self, $oldDomainName, $newDomainName) = @_;
}

# Method: fqdnChanged
#
#   Invoked before the change takes place. Any module implementing this
#   method can abort the change throwing an exception.
#   This is called after the methods hostNameChanged and hostDomainChanged.
#
# Parameters:
#
#   oldDomainName
#   newDomainName
#
sub fqdnChanged
{
    my ($self, $oldFqdn, $newFqdn) = @_;
}

# Method: fqdnChangedDone
#
#   Invoked after the change takes place
#   This is called after the methods hostnameChangedDone and hostDomainChangedDone.
#
# Parameters:
#
#   oldDomainName
#   newDomainName
#
sub fqdnChangedDone
{
    my ($self, $oldFqdn, $newFqdn) = @_;
}

1;
