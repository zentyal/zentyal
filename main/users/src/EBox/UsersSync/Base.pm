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

# Class: EBox::UsersSync::Base
#
#    These methods will be called when a user or group is added,
#    modified or deleted. They can be implemented in order to sync
#    that changes to other machines (master provider).
#
#    Slave implementation should call UsersAndGroups methods in order
#    to make the desired changes
#
package EBox::UsersSync::Base;

use strict;
use warnings;

use base 'EBox::LdapUserBase';

use EBox::Exceptions::Internal;
use EBox::Exceptions::NotImplemented;

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = {};

    $self->{name} = delete $opts{name};
    $self->{printableName} = delete $opts{printableName};
    unless (defined($self->{name})) {
        throw EBox::Exceptions::Internal('No name provided');
    }

    bless($self, $class);
    return $self;
}


# Method: confLink
#
#   Return a link to the configuration of this synchronizer
#
sub confLink
{
    throw EBox::Exceptions::NotImplemented();
}


1;
