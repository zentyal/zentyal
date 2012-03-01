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

# Class: EBox::UsersAndGroups::Slave
#
#    These methods will be called when a user or group is added,
#    modified or deleted. They can be implemented in order to sync
#    that changes to other machines (master provider).
#
package EBox::UsersAndGroups::Slave;

use strict;
use warnings;

use base 'EBox::LdapUserBase';

use EBox::Exceptions::Internal;
use EBox::Exceptions::NotImplemented;


# Method: new
#
#   Create a new slave instance, choosen name should
#   be unique between all the slaves
#
sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = {};

    $self->{name} = delete $opts{name};
    unless (defined($self->{name})) {
        throw EBox::Exceptions::Internal('No name provided');
    }

    bless($self, $class);
    return $self;
}


sub name
{
    my ($self) = @_;
    return $self->{name};
}

1;
