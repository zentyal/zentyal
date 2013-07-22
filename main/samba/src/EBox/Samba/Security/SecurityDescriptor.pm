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

# Class: EBox::Samba::Security::SecurityDescriptor
#
#   This is a helper class to generate security descriptors, in binary format
#   or SDDL string format (Security Descriptor Definition Language).
#
#   A security descriptor is a structure and associated data that contains
#   the security information for a securable object. A security descriptor
#   identifies the object's owner and primary group. It can also contain
#   a DACL (discretionary access control list) that controls access to the
#   object, and a SACL (system access control list) that controls the logging
#   of attempts to access the object.
#
#   Documentation:
#
#   [MS-DTYP] — v20130118
#       Windows Data Types
#       Copyright © 2013 Microsoft Corporation.
#
package EBox::Samba::Security::SecurityDescriptor;

use EBox::Samba::Security::ACL::Discretionary;
use EBox::Samba::Security::ACL::System;
use EBox::Samba::Security::SID;

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidArgument;
use EBox::Exceptions::Internal;

use Error qw(:try);

use constant CONTROL_OD => (1<<0);
use constant CONTROL_GD => (1<<1);
use constant CONTROL_DP => (1<<2);
use constant CONTROL_DD => (1<<3);
use constant CONTROL_SP => (1<<4);
use constant CONTROL_SD => (1<<5);
use constant CONTROL_SS => (1<<6);
use constant CONTROL_DT => (1<<7);
use constant CONTROL_DC => (1<<8);
use constant CONTROL_SC => (1<<9);
use constant CONTROL_DI => (1<<10);
use constant CONTROL_SI => (1<<11);
use constant CONTROL_PD => (1<<12);
use constant CONTROL_PS => (1<<13);
use constant CONTROL_RM => (1<<14);
use constant CONTROL_SR => (1<<15);

sub new
{
    my ($class, %params) = @_;

    my $self = {};
    bless ($self, $class);

    unless (defined $params{blob} or
        (defined $params{ownerSID} and defined $params{groupSID})) {
        throw EBox::Exceptions::MissingArgument(
            'blob | (ownerSID & groupSID)');
    }

    if (defined $params{blob}) {
        $self->_decode($params{blob});
    } else {
        $self->setOwnerSID($params{ownerSID});
        $self->setGroupSID($params{groupSID});
        $self->{sacl} = new EBox::Samba::Security::ACL::Discretionary();
        $self->{dacl} = new EBox::Samba::Security::ACL::System();
    }

    return $self;
}

# Method: setOwnerSID
#
#   Set the SID that identifies the object's owner
#
sub setOwnerSID
{
    my ($self, $ownerSID) = @_;

    unless (defined $ownerSID) {
        throw EBox::Exceptions::MissingArgument('ownerSID');
    }

    unless ($ownerSID->isa('EBox::Samba::Security::SID')) {
        throw EBox::Exceptions::InvalidArgument(
            'ownerSID (Expected EBox::Samba::Security::SID instance)');
    }

    $self->{ownerSID} = $ownerSID;
}

# Method: setGroupSID
#
#   Set the SID that identifies the object's primary group
#
sub setGroupSID
{
    my ($self, $groupSID) = @_;

    unless (defined $groupSID) {
        throw EBox::Exceptions::MissingArgument('groupSID');
    }

    unless ($groupSID->isa('EBox::Samba::Security::SID')) {
        throw EBox::Exceptions::InvalidArgument(
            'groupSID (Expected EBox::Samba::Security::SID instance)');
    }

    $self->{groupSID} = $groupSID;
}

# Method: addDiscretionaryACE
#
#   Adds an ACE (Access Control Entry) to the discretionary ACL
#
sub addDiscretionaryACE
{
    my ($self, $ace) = @_;

    unless (defined $ace) {
        throw EBox::Eceptions::MissingArgument('ace');
    }
    unless ($ace->isa('EBox::Samba::Security::ACE')) {
        throw EBox::Exceptions::InvalidArgument(
            'ace (Expected EBox::Samba::Security::ACE instance)');
    }

    my $acl = $self->{dacl};
    $acl->addACE($ace);
}

# Method: addSystemACE
#
#   Adds an ACE (Access Control Entry) to the system ACL
#
sub addSystemACE
{
    my ($self, $ace) = @_;

    unless (defined $ace) {
        throw EBox::Eceptions::MissingArgument('ace');
    }
    unless ($ace->isa('EBox::Samba::Security::ACE')) {
        throw EBox::Exceptions::InvalidArgument(
            'ace (Expected EBox::Samba::Security::ACE instance)');
    }

    my $acl = $self->{sacl};
    $acl->addACE($ace);
}

# Method: _decode
#
#   Decodes a binary blob containing a security descriptor
#
# Documentation:
#
#   [MS-DTYP] Section 2.4.6
#
sub _decode
{
    my ($self, $blob) = @_;

    # Revision (1 byte):
    # An unsigned 8-bit value that specifies the revision of the
    # SECURITY_DESCRIPTOR structure. This field MUST be set to one.
    my $revision;

    # Sbz1 (1 byte):
    # An unsigned 8-bit value with no meaning unless the Control RM bit is set
    # to 0x1. If the RM bit is set to 0x1, Sbz1 is interpreted as the resource
    # manager control bits that contain specific information<53> for the
    # specific resource manager that is accessing the structure. The
    # permissible values and meanings of these bits are determined by the
    # implementation of the resource manager.
    my $sbz1;

    # Control (2 bytes):
    # An unsigned 16-bit field that specifies control access bit flags. The
    # Self Relative (SR) bit MUST be set when the security descriptor is in
    # self-relative format.
    my $control;

    # OffsetOwner (4 bytes):
    # An unsigned 32-bit integer that specifies the offset to the SID. This
    # SID specifies the owner of the object to which the security descriptor
    # is associated. This must be a valid offset if the OD flag is not set.
    # If this field is set to zero, the OwnerSid field MUST not be present.
    my $offsetOwner;

    # OffsetGroup (4 bytes):
    # An unsigned 32-bit integer that specifies the offset to the SID. This
    # SID specifies the group of the object to which the security descriptor
    # is associated. This must be a valid offset if the GD flag is not set.
    # If this field is set to zero, the GroupSid field MUST not be present.
    my $offsetGroup;

    # OffsetSacl (4 bytes):
    # An unsigned 32-bit integer that specifies the offset to the ACL that
    # contains system ACEs. Typically, the system ACL contains auditing ACEs
    # (such as SYSTEM_AUDIT_ACE, SYSTEM_AUDIT_CALLBACK_ACE, or
    # SYSTEM_AUDIT_CALLBACK_OBJECT_ACE), and at most one Label ACE (as
    # specified in section 2.4.4.13). This must be a valid offset if the SP
    # flag is set; if the SP flag is not set, this field MUST be set to zero.
    # If this field is set to zero, the Sacl field MUST not be present.
    my $offsetSACL;

    # OffsetDacl (4 bytes):
    # An unsigned 32-bit integer that specifies the offset to the ACL that
    # contains ACEs that control access. Typically, the DACL contains ACEs
    # that grant or deny access to principals or groups. This must be a valid
    # offset if the DP flag is set; if the DP flag is not set, this field MUST
    # be set to zero. If this field is set to zero, the Dacl field MUST not be
    # present.
    my $offsetDACL;

    # OwnerSid (variable):
    # The SID of the owner of the object. The length of the SID MUST be a
    # multiple of 4. This field MUST be present if the OffsetOwner field is
    # not zero.
    my $ownerSID;

    # GroupSid (variable):
    # The SID of the group of the object. The length of the SID MUST be a
    # multiple of 4. This field MUST be present if the GroupOwner field is not
    # zero.
    my $groupSID;

    # Sacl (variable):
    # The SACL of the object. The length of the SID MUST be a multiple of 4.
    # This field MUST be present if the SP flag is set.
    my $sacl;

    # Dacl (variable):
    # The DACL of the object. The length of the SID MUST be a multiple of 4.
    # This field MUST be present if the DP flag is set.
    my $dacl;

    my $fmt = 'C C S L L L L ';
    ($revision, $sbz1, $control, $offsetOwner, $offsetGroup, $offsetSACL,
     $offsetDACL, $ownerSID, $groupSID, $sacl, $dacl) = unpack ($fmt, $blob);

    EBox::debug("Revision:    <$revision>");
    EBox::debug("Sbz1:        <$sbz1>");
    EBox::debug("Control:     <$control>");
    EBox::debug("OffsetOwner: <$offsetOwner>");
    EBox::debug("OffsetGroup: <$offsetGroup>");
    EBox::debug("OffsetSACL:  <$offsetSACL>");
    EBox::debug("OffsetDACL:  <$offsetDACL>");

    unless ($revision == 1) {
        throw EBox::Exceptions::Internal(
            "Invalid security descriptor revision. Was $revision, expected 1");
    }

    if ($offsetOwner != 0) {
        EBox::debug("Decoding owner SID");
        my $sid = new EBox::Samba::Security::SID(
            blob => $blob, blobOffset => $offsetOwner);
        $self->{ownerSID} = $sid;
    }

    if ($offsetGroup != 0) {
        EBox::debug("Decoding primary group SID");
        my $sid = new EBox::Samba::Security::SID(
            blob => $blob, blobOffset => $offsetGroup);
        $self->{groupSID} = $sid;
    }

    if (($control & CONTROL_SP) and $offsetSACL != 0) {
        EBox::debug("Decoding system ACL");
        my $acl = new EBox::Samba::Security::ACL::System(
            blob => $blob, blobOffset => $offsetSACL);
        $self->{sacl} = $acl;
    }

    if (($control & CONTROL_DP) and $offsetDACL != 0) {
        EBox::debug("Decoding discretionary ACL");
        my $acl = new EBox::Samba::Security::ACL::Discretionary(
            blob => $blob, blobOffset => $offsetDACL);
        $self->{dacl} = $acl;
    }
}

1;
