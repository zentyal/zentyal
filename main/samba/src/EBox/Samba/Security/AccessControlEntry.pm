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

# Class: EBox::Samba::Security::AccessControlEntry
#
#   This is a helper class to generate ACE entries (an entry in an access control list).
#   An ACE contains a set of access rights and a security identifier (SID) that identifies
#   a trustee for whom the rights are allowed, denied, or audited.
#
#   Documentation:
#   http://msdn.microsoft.com/en-us/library/windows/desktop/aa374928%28v=vs.85%29.aspx
#
package EBox::Samba::Security::AccessControlEntry;

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidArgument;
use EBox::Exceptions::NotImplemented;
use EBox::Samba::Security::SecurityDescriptor;

use Error qw(:try);

#
# ACE types valid tokens
# Commented entries are not implemented in samba (libcli/security/sddl.c)
#
my $aceTypes = {
    'A'   => 'ACCESS_ALLOWED',
    'D'   => 'ACCESS_DENIED',
    'OA'  => 'OBJECT_ACCESS_ALLOWED',
    'OD'  => 'OBJECT_ACCESS_DENIED',
    'AU'  => 'AUDIT',
    'AL'  => 'ALARM',
    'OU'  => 'OBJECT_AUDIT',
    'OL'  => 'OBJECT_ALARM',
#   'ML'  => 'MANDATORY_LABEL',
#   'XA'  => 'CALLBACK_ACCESS_ALLOWED',        # Windows Vista and Windows Server 2003:  Not available.
#   'XD'  => 'CALLBACK_ACCESS_DENIED',         # Windows Vista and Windows Server 2003:  Not available.
#   'RA'  => 'RESOURCE_ATTRIBUTE',             # Windows Server 2008 R2, Windows 7, Windows Server 2008, Windows Vista, and Windows Server 2003:  Not available.
#   'SP'  => 'SCOPED_POLICY_ID',               # Windows Server 2008 R2, Windows 7, Windows Server 2008, Windows Vista, and Windows Server 2003:  Not available.
#   'XU'  => 'CALLBACK_AUDIT',                 # Windows Server 2008 R2, Windows 7, Windows Server 2008, Windows Vista, and Windows Server 2003:  Not available.
#   'ZA'  => 'CALLBACK_OBJECT_ACCESS_ALLOWED', # Windows Server 2008 R2, Windows 7, Windows Server 2008, Windows Vista, and Windows Server 2003:  Not available.
};

#
# ACE flags valid tokens
#
my $aceFlags = {
    'CI' => 'CONTAINER_INHERIT',
    'OI' => 'OBJECT_INHERIT',
    'NP' => 'NO_PROPAGATE',
    'IO' => 'INHERIT_ONLY',
    'ID' => 'INHERITED',
    'SA' => 'AUDIT_SUCCESS',
    'FA' => 'AUDIT_FAILURE',
};

#
# ACE rights valid tokens
#
my $aceRights = {
    # Generic Access Rights
    GA => "GENERIC_ALL",
    GR => "GENERIC_READ",
    GW => "GENERIC_WRITE",
    GX => "GENERIC_EXECUTE",

    # Standard Access Rights
    RC => "STANDARD_READ_CONTROL",
    SD => "STANDARD_DELETE",
    WD => "STANDARD_WRITE_DAC",
    WO => "STANDARD_WRITE_OWNER",

    # Directory Service Object Access Rights
    RP => "DS_READ_PROPERTY",
    WP => "DS_WRITE_PROPERTY",
    CC => "DS_CREATE_CHILD",
    DC => "DS_DELETE_CHILD",
    LC => "DS_LIST_CHILDREN",
    SW => "DS_SELF_WRITE",
    LO => "DS_LIST_OBJECT",
    DT => "DS_DELETE_TREE",
    CR => 'DS_CONTROL_ACCESS',

    # File Access Rights
    FA => "FILE_ALL_ACCESS",
    FR => "FILE_GENERIC_READ",
    FW => "FILE_GENERIC_WRITE",
    FX => "FILE_GENERIC_EXECUTE",

#   # Registry Access Rights
#   KA => "KEY_ALL_ACCESS",
#   KR => "KEY_READ",
#   KW => "KEY_WRITE",
#   KX => "KEY_EXECUTE",

#   # Mandatory Label Rights
#   MR => 'LABEL_NO_READ_UP',
#   MW => 'LABEL_NO_WRITE_UP',
#   NX => 'LABEL_NO_EXECUTE_UP',
};

sub new
{
    my ($class, %params) = @_;

    unless (defined $params{type}) {
        throw EBox::Exceptions::MissingArgument('type');
    }
    unless (defined $params{flags}) {
        throw EBox::Exceptions::MissingArgument('flags');
    }
    unless (defined $params{rights}) {
        throw EBox::Exceptions::MissingArgument('rights');
    }
    unless (defined $params{objectSID}) {
        throw EBox::Exceptions::MissingArgument('objectSID');
    }

    my $self = {};
    bless ($self, $class);

    $self->setType($params{type});
    $self->setFlags($params{flags});
    $self->setRights($params{rights});
    $self->setObjectSID($params{objectSID});

    if (defined $params{objectGUID}) {
        $self->setObjectGUID($params{objectGUID});
    }
    if (defined $params{inheritObjectGUID}) {
        $self->setInheritObjectGUID($params{inheritObjectGUID});
    }

    return $self;
}

# Method: setType
#
#   Sets the string that indicates the value of the AceType member of the ACE_HEADER structure.
#   This string is one of the keys of the hash $aceTypes
#
sub setType
{
    my ($self, $type) = @_;

    unless (defined $type) {
        throw EBox::Exceptions::MissingArgument('type');
    }
    unless (exists $aceTypes->{$type}) {
        throw EBox::Exceptions::InvalidArgument('ACE type', $type);
    }
    $self->{type} = $type;
}

# Method: setFlags
#
#   Sets the string that indicates the value of the AceFlags member of the ACE_HEADER structure.
#   This string is a concatenation of one or more keys of the hash $aceFlags
#
sub setFlags
{
    my ($self, $flags) = @_;

    unless (scalar @{$flags}) {
        throw EBox::Exceptions::MissingArgument('flags');
    }
    foreach my $flag (@{$flags}) {
        unless (exists $aceFlags->{$flag}) {
            throw EBox::Exceptions::InvalidArgument('ACE flag', $flag);
        }
    }
    $self->{flags} = join ('', @{$flags});
}

# Method: setRights
#
#   Sets the string that indicates the access rights controlled by the ACE.
#   This string is a concatenation of one or more keys of the hash $aceRights
#
sub setRights
{
    my ($self, $rights) = @_;

    unless (scalar @{$rights}) {
        throw EBox::Exceptions::MissingArgument('rights');
    }
    foreach my $token (@{$rights}) {
        unless (exists $aceRights->{$token}) {
            throw EBox::Exceptions::InvalidArgument('ACE Access Right', $token);
        }
    }
    $self->{rights} = join ('', @{$rights});
}

# Method: setObjectGUID
#
#   Sets the string representation of a GUID that indicates the value of the
#   ObjectType member of an object-specific ACE structure, such as
#   ACCESS_ALLOWED_OBJECT_ACE. The GUID string uses the format returned
#   by the UuidToString function.
#
sub setObjectGUID
{
    my ($self, $guid) = @_;

    throw EBox::Exceptions::NotImplemented();
}

# Method: setInheritObjectGUID
#
#   Sets the string representation of a GUID that indicates the value of the
#   InheritedObjectType member of an object-specific ACE structure.
#   The GUID string uses the UuidToString format.
#
sub setInheritObjectGUID
{
    my ($self, $guid) = @_;

    throw EBox::Exceptions::NotImplemented();
}

# Method: setObjectSID
#
#   SID string that identifies the trustee of the ACE.
#
# Parameters:
#
#   accountSID - Can be either a key of the hash $sidStrings or a SID string
#
sub setObjectSID
{
    my ($self, $sid) = @_;

    my $sidStrings = $EBox::Samba::Security::SecurityDescriptor::sidStrings;

    unless (defined $sid) {
        throw EBox::Exceptions::MissingArgument('sid');
    }
    if (length $sid == 2) {
        unless (exists $sidStrings->{$sid}) {
            throw EBox::Exceptions::InvalidArgument('SID String', $sid);
        }
    }
    # TODO Validate SID string

    $self->{objectSID} = $sid;
}

sub getAsString
{
    my ($self) = @_;

    my $string = '';
    $string .= $self->{type};
    $string .= ';';
    $string .= $self->{flags};
    $string .= ';';
    $string .= $self->{rights};
    $string .= ';';
    if (defined $self->{objectGUID}) {
        $string .= $self->{objectGUID};
    }
    $string .= ';';
    if (defined $self->{inheritObjectGUID}) {
        $string .= $self->{inheritObjectGUID};
    }
    $string .= ';';
    $string .= $self->{objectSID};

    return $string;
}

1;
