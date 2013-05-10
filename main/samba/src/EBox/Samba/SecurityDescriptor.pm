# Copyright (C) 2013 eBox Technologies S.L.
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


# Class: EBox::Samba::SecurityDescriptor
#
#   This is a helper class to generate security descriptors strings, based
#   on the SDDL (Security Descriptor Definition Language).
#
#   A security descriptor is a structure and associated data that contains
#   the security information for a securable object. A security descriptor
#   identifies the object's owner and primary group. It can also contain
#   a DACL (discretionary access control list) that controls access to the
#   object, and a SACL (system access control list) that controls the logging
#   of attempts to access the object.
#
#   Documentation:
#   http://msdn.microsoft.com/en-us/library/windows/desktop/aa379567%28v=vs.85%29.aspx
#
package EBox::Samba::SecurityDescriptor;

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidArgument;

use Error qw(:try);

# Security descriptor control flags that apply to the DACL or SACL
my $aclFlags = {
    P  => 'PROTECTED',        # The SE_DACL_PROTECTED flag is set
    AR => 'AUTO_INHERIT_REQ', # The SE_DACL_AUTO_INHERIT_REQ flag is set
    AI => 'AUTO_INHERITED',   # The SE_DACL_AUTO_INHERITED flag is set
    NO_ACCESS_CONTROL => 'SSDL_NULL_ACL', # The ACL is null.
};


sub new
{
    my ($class, %params) = @_;

    unless (defined $params{ownerSID}) {
        throw EBox::Exceptions::MissingArgument('ownerSID');
    }
    unless (defined $params{groupSID}) {
        throw EBox::Exceptions::MisssinArgument('groupSID');
    }

    my $self = {};
    bless ($self, $class);

    $self->setOownerSID($params{ownerSID});
    $self->setGroupSID($params{groupSID});

    $self->{saclFlags} = '';
    $self->{daclFlags} = 'PAI';
    $self->{sacl} = [];
    $self->{dacl} = [];


    return $self;
}

# Method: setOwnerSID
#
#   Set the SID string that identifies the object's owner
#
sub setOwnerSID
{
    my ($self, $ownerSID) = @_;

    unless (defined $ownerSID) {
        throw EBox::Exceptions::MissingArgument('ownerSID');
    }

    if (length $ownerSID == 2) {
        unless (exists $sidStrings->{$ownerSID}) {
            throw EBox::Exceptions::InvalidArgument('SID String', $ownerSID);
        }
    }

    # TODO Validate SID format

    $self->{ownerSID} = $ownerSID;
}

# Method: setGroupSID
#
#   Set the SID string that identifies the object's primary group
#
sub setGroupSID
{
    my ($self, $groupSID) = @_;

    unless (defined $groupSID) {
        throw EBox::Exceptions::MissingArgument('groupSID');
    }

    if (length $groupSID == 2) {
        unless (exists $sidStrings->{$groupSID}) {
            throw EBox::Exceptions::InvalidArgument('SID String', $groupSID);
        }
    }

    # TODO Validate SID format

    $self->{groupSID} = $groupSID;
}

# Method: setDACLFlags
#
#   Security descriptor control flags that apply to the DACL.
#   The flags string can be a concatenation of zero or more of the
#   keys defined in the hash $daclFlags
#
sub setDACLFlags
{
    my ($self, $flags) = @_;

    unless (defined $flags) {
        throw EBox::Exceptions::MissingArgument('flags');
    }

    # TODO Validate flags
    $self->{daclFlags} = $flags;
}

# Method: setSACLFlags
#
#   Set the Security descriptor control flags that apply to the SACL.
#   The flags string uses the same control bit strings as the dacl_flags string.
#
sub setSACLFlags
{
    my ($self, $flags) = @_;

    unless (defined $flags) {
        throw EBox::Exceptions::MissingArgument('flags');
    }

    # TODO Validate flags
    $self->{saclFlags} = $flags;
}

# Method: addDACL
#
#   Adds an ACE (Access Control Entry) to the DACL list
#
sub addDACL
{
    my ($self, $ace) = @_;

    unless (defined $ace) {
        throw EBox::Eceptions::MissingArgument('ace');
    }
    unless ($ace->isa('EBox::Samba::AccessControlEntry') {
        throw EBox::Exceptions::InvalidArgument('ace');
    }
    push (@{$self->{dacl}}, $ace);
}

# Method: addSCAL
#
#   Adds an ACE to the SACL list
#
sub addSACL
{
    my ($self, $ace) = @_;

    unless (defined $ace) {
        throw EBox::Eceptions::MissingArgument('ace');
    }
    unless ($ace->isa('EBox::Samba::AccessControlEntry') {
        throw EBox::Exceptions::InvalidArgument('ace');
    }
    push (@{$self->{sacl}}, $ace);
}


sub getAsString
{
    my ($self) = @_;

    my $string = '';
    $string .= ('O:' . $self->{ownerSID});
    $string .= ';';

    $string .= ('G:' . $self->{groupSID});
    $string .= ';';

    if (scalar @{$self->{dacl}}) {
        $string .= ('D:' . $self->{daclFlags});
        foreach my $ace (@{$self->{dacl}}) {
            $string .= ('(' . $ace->getAsString() . ')');
        }
    }

    if (scalar @{$self->{sacl}}) {
        $string .= ('S:' . $self->{saclFlags});
        foreach my $ace (@{$self->{sacl}}) {
            $string .= ('(' . $ace->getAsString() . ')');
        }
    }

    return $string;
}

1;
