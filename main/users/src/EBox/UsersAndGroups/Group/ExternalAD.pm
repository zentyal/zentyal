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
#
package EBox::UsersAndGroups::Group::ExternalAD;
use base 'EBox::UsersAndGroups::Group';

use EBox::Gettext;
use EBox::Exceptions::UnwillingToPerform;


use Error qw(:try);

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = {};

    if (defined $opts{gid}) {
        $self->{gid} = $opts{gid};
    } else {
        $self = $class->SUPER::new(@_);
    }

    bless ($self, $class);
    return $self;
}

sub mainObjectClass
{
    return 'group';
}

sub dnComponent
{
    return 'cn=Users'; # same than users
}

sub userClass
{
    return 'EBox::UsersAndGroups::User::ExternalAD';
}

# Method: name
#
#   Return group name
#
sub name
{
    my ($self) = @_;
    return $self->get('name');
}

sub system
{
    my ($self) = @_;

    # XXX look gor more attributes
    return $self->get('isCriticalSystemObject');
}

sub addMember
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'Cannot add members to a external AD group')
}

sub removeMember
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'Cannot remove members from a external AD group')
}

sub set
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD group are readonly')
}

sub add
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD group are readonly')
}

sub delete
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD group are readonly')
}

sub deleteValues
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD group are readonly')
}

sub deleteObjects
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD group are readonly')
}

sub save
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD group are readonly')
}


1;
