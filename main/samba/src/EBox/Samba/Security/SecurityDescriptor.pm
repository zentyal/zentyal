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
package EBox::Samba::Security::SecurityDescriptor;

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidArgument;

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

#
# Security descriptor control flags that apply to the DACL or SACL
#
my $aclFlags = {
    P  => 'PROTECTED',        # The SE_DACL_PROTECTED flag is set
    AR => 'AUTO_INHERIT_REQ', # The SE_DACL_AUTO_INHERIT_REQ flag is set
    AI => 'AUTO_INHERITED',   # The SE_DACL_AUTO_INHERITED flag is set
};

#
# ACE or security descriptor valid SID tokens
# Commented entries are not implemented in samba (libcli/security/sddl.c)
#
our $sidStrings = {
    AN  =>  'ANONYMOUS',                        # Anonymous logon. The corresponding RID is SECURITY_ANONYMOUS_LOGON_RID.
    AO  =>  'ACCOUNT_OPERATORS',                # Account operators. The corresponding RID is DOMAIN_ALIAS_RID_ACCOUNT_OPS.
    AU  =>  'AUTHENTICATED_USERS',              # Authenticated users. The corresponding RID is SECURITY_AUTHENTICATED_USER_RID.
    BA  =>  'BUILTIN_ADMINISTRATORS',           # Built-in administrators. The corresponding RID is DOMAIN_ALIAS_RID_ADMINS.
    BG  =>  'BUILTIN_GUESTS',                   # Built-in guests. The corresponding RID is DOMAIN_ALIAS_RID_GUESTS.
    BO  =>  'BACKUP_OPERATORS',                 # Backup operators. The corresponding RID is DOMAIN_ALIAS_RID_BACKUP_OPS.
    BU  =>  'BUILTIN_USERS',                    # Built-in users. The corresponding RID is DOMAIN_ALIAS_RID_USERS.
    CA  =>  'CERT_SERV_ADMINISTRATORS',         # Certificate publishers. The corresponding RID is DOMAIN_GROUP_RID_CERT_ADMINS.
#   CD  =>  'CERTSVC_DCOM_ACCESS',              # Users who can connect to certification authorities using Distributed Component Object Model (DCOM).
                                                # The corresponding RID is DOMAIN_ALIAS_RID_CERTSVC_DCOM_ACCESS_GROUP.
    CG  =>  'SDDL_CREATOR_GROUP',               # Creator group. The corresponding RID is SECURITY_CREATOR_GROUP_RID.
    CO  =>  'CREATOR_OWNER',                    # Creator owner. The corresponding RID is SECURITY_CREATOR_OWNER_RID.
    DA  =>  'DOMAIN_ADMINISTRATORS',            # Domain administrators. The corresponding RID is DOMAIN_GROUP_RID_ADMINS.
    DC  =>  'DOMAIN_COMPUTERS',                 # Domain computers. The corresponding RID is DOMAIN_GROUP_RID_COMPUTERS.
    DD  =>  'DOMAIN_DOMAIN_CONTROLLERS',        # Domain controllers. The corresponding RID is DOMAIN_GROUP_RID_CONTROLLERS.
    DG  =>  'DOMAIN_GUESTS',                    # Domain guests. The corresponding RID is DOMAIN_GROUP_RID_GUESTS.
    DU  =>  'DOMAIN_USERS',                     # Domain users. The corresponding RID is DOMAIN_GROUP_RID_USERS.
    EA  =>  'ENTERPRISE_ADMINS',                # Enterprise administrators. The corresponding RID is DOMAIN_GROUP_RID_ENTERPRISE_ADMINS.
    ED  =>  'ENTERPRISE_DOMAIN_CONTROLLERS',    # Enterprise domain controllers. The corresponding RID is SECURITY_SERVER_LOGON_RID.
#   HI  =>  'ML_HIGH',                          # High integrity level. The corresponding RID is SECURITY_MANDATORY_HIGH_RID.
    IU  =>  'INTERACTIVE',                      # Interactively logged-on user. This is a group identifier added to the token of a
                                                # process when it was logged on interactively. The corresponding logon type is LOGON32_LOGON_INTERACTIVE.
                                                # The corresponding RID is SECURITY_INTERACTIVE_RID.
    LA  =>  'LOCAL_ADMIN',                      # Local administrator. The corresponding RID is DOMAIN_USER_RID_ADMIN.
    LG  =>  'LOCAL_GUEST',                      # Local guest. The corresponding RID is DOMAIN_USER_RID_GUEST.
    LS  =>  'LOCAL_SERVICE',                    # Local service account. The corresponding RID is SECURITY_LOCAL_SERVICE_RID.
#   LW  =>  'ML_LOW',                           # Low integrity level. The corresponding RID is SECURITY_MANDATORY_LOW_RID.
#   ME  =>  'MLMEDIUM',                         # Medium integrity level. The corresponding RID is SECURITY_MANDATORY_MEDIUM_RID.
#   MU  =>  'PERFMON_USERS',                    # Performance Monitor users.
    NO  =>  'NETWORK_CONFIGURATION_OPS',        # Network configuration operators. The corresponding RID is DOMAIN_ALIAS_RID_NETWORK_CONFIGURATION_OPS.
    NS  =>  'NETWORK_SERVICE',                  # Network service account. The corresponding RID is SECURITY_NETWORK_SERVICE_RID.
    NU  =>  'NETWORK',                          # Network logon user. This is a group identifier added to the token of a process when it was logged on across a network.
                                                # The corresponding logon type is LOGON32_LOGON_NETWORK. The corresponding RID is SECURITY_NETWORK_RID.
    PA  =>  'GROUP_POLICY_ADMINS',              # Group Policy administrators. The corresponding RID is DOMAIN_GROUP_RID_POLICY_ADMINS.
    PO  =>  'PRINTER_OPERATORS',                # Printer operators. The corresponding RID is DOMAIN_ALIAS_RID_PRINT_OPS.
    PS  =>  'PERSONAL_SELF',                    # Principal self. The corresponding RID is SECURITY_PRINCIPAL_SELF_RID.
    PU  =>  'POWER_USERS',                      # Power users. The corresponding RID is DOMAIN_ALIAS_RID_POWER_USERS.
    RC  =>  'RESTRICTED_CODE',                  # Restricted code. This is a restricted token created using the CreateRestrictedToken function.
                                                # The corresponding RID is SECURITY_RESTRICTED_CODE_RID.
    RD  =>  'REMOTE_DESKTOP',                   # Terminal server users. The corresponding RID is DOMAIN_ALIAS_RID_REMOTE_DESKTOP_USERS.
    RE  =>  'REPLICATOR',                       # Replicator. The corresponding RID is DOMAIN_ALIAS_RID_REPLICATOR.
    RO  =>  'ENTERPRISE_RO_DCs',                # Enterprise Read-only domain controllers. The corresponding RID is DOMAIN_GROUP_RID_ENTERPRISE_READONLY_DOMAIN_CONTROLLERS.
#   RS  =>  'RAS_SERVERS RAS',                  # servers group. The corresponding RID is DOMAIN_ALIAS_RID_RAS_SERVERS.
    RU  =>  'ALIAS_PREW2KCOMPACC',              # Alias to grant permissions to accounts that use applications compatible with operating systems previous to Windows 2000.
                                                # The corresponding RID is DOMAIN_ALIAS_RID_PREW2KCOMPACCESS.
    SA  =>  'SCHEMA_ADMINISTRATORS',            # Schema administrators. The corresponding RID is DOMAIN_GROUP_RID_SCHEMA_ADMINS.
#   SI  =>  'ML_SYSTEM',                        # System integrity level. The corresponding RID is SECURITY_MANDATORY_SYSTEM_RID.
    SO  =>  'SERVER_OPERATORS',                 # Server operators. The corresponding RID is DOMAIN_ALIAS_RID_SYSTEM_OPS.
    SU  =>  'SERVICE',                          # Service logon user. This is a group identifier added to the token of a process when it was logged as a service.
                                                # The corresponding logon type is LOGON32_LOGON_SERVICE. The corresponding RID is SECURITY_SERVICE_RID.
    SY  =>  'LOCAL_SYSTEM',                     # Local system. The corresponding RID is SECURITY_LOCAL_SYSTEM_RID.
    WD  =>  'EVERYONE',                         # Everyone. The corresponding RID is SECURITY_WORLD_RID
};

sub new
{
    my ($class, %params) = @_;

    my $self = {};
    bless ($self, $class);

    unless (defined $params{blob} or (defined $params{ownerSID} and defined $params{groupSID})) {
        throw EBox::Exceptions::MissingArgument(' blob | (ownerSID && groupSID)');
    }

    if (defined $params{blob}) {
        $self->decodeBlob($params{blob});
    } else {
        $self->setOwnerSID($params{ownerSID});
        $self->setGroupSID($params{groupSID});

        $self->{saclFlags} = '';
        $self->{daclFlags} = 'PAI';
        $self->{sacl} = [];
        $self->{dacl} = [];
    }

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
    unless ($ace->isa('EBox::Samba::Security::AccessControlEntry')) {
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
    unless ($ace->isa('EBox::Samba::AccessControlEntry')) {
        throw EBox::Exceptions::InvalidArgument('ace');
    }
    push (@{$self->{sacl}}, $ace);
}


sub getAsString
{
    my ($self) = @_;

    my $string = '';
    $string .= ('O:' . $self->{ownerSID});

    $string .= ('G:' . $self->{groupSID});

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

# Method: decodeSID
#
#   Decodes a SID inside a security descriptor binary blob at a given offset.
#
# Documentation:
#
#   [MS-DTYP] Section 2.4.2.2
#
sub decodeSID
{
    my ($self, $blob, $offset) = @_;

    # Revision (1 byte):
    # An 8-bit unsigned integer that specifies the revision level of the SID.
    # This value MUST be set to 0x01.
    my $revision;

    # SubAuthorityCount (1 byte):
    # An 8-bit unsigned integer that specifies the number of elements in the
    # SubAuthority array. The maximum number of elements allowed is 15.
    my $subAuthorityCount;


    # IdentifierAuthority (6 bytes):
    # A SID_IDENTIFIER_AUTHORITY structure that indicates the authority under
    # which the SID was created. It describes the entity that created the SID.
    # The Identifier Authority value {0,0,0,0,0,5} denotes SIDs created by the
    # NT SID authority.
    my $identifierAuthority;

    # SubAuthority (variable):
    # A variable length array of unsigned 32-bit integers that uniquely
    # identifies a principal relative to the IdentifierAuthority. Its length
    # is determined by SubAuthorityCount.
    my @subAuthority;

    my $fmt = "\@$offset(C C)";
    (undef, $subAuthorityCount) = unpack($fmt, $blob);

    $fmt = "\@$offset(C C a6 L$subAuthorityCount)";
    ($revision, undef, $identifierAuthority, @subAuthority) =
        unpack($fmt, $blob);

    $identifierAuthority = hex(unpack('H*', $identifierAuthority));

    EBox::debug("Revision:               <$revision>");
    EBox::debug("SubAuthorityCount:      <$subAuthorityCount>");
    EBox::debug("IdentifierAuthority:    <$identifierAuthority>");
    foreach my $subAuthority (@subAuthority) {
        EBox::debug("SubAuthority:           <$subAuthority>");
    }

    my $sid = "S-1-$identifierAuthority-" . join ('-', @subAuthority);
    EBox::debug("Decoded SID: $sid");
    return $sid;
}

sub decodeACL
{
    my ($self, $blob, $aceCount) = @_;

    my $aceType;
    my $aceFlags;
    my $aceSize;

    EBox::debug("===> $count");
    my $aceOffset = 0;
    for (my $i=0; $i<$aceCount; $i++) {
        my $fmt = "\@$aceOffset(C C S)";
        ($aceType, $aceFlags, $aceSize) = unpack($fmt, $blob);
        EBox::debug("AceType:   <$aceType>");
        EBox::debug("AceFlags:  <$aceFlags>");
        EBox::debug("AceSize:   <$aceSize>");
        $aceOffset += ($aceSize + 4);
    }
}

sub decodeSACL
{
    my ($self, $blob, $offset) = @_;

    my $revision;
    my $sbz1;
    my $aclSize;
    my $aceCount;
    my $sbz2;

    my $fmt = "\@$offset(C C S S S)";
    ($revision, $sbz1, $aclSize, $aceCount, $sbz2) = unpack($fmt, $blob);
    $offset += 8;

    EBox::debug("Revision:  <$revision>");
    EBox::debug("Sbz1:      <$sbz1>");
    EBox::debug("AclSize:   <$aclSize>");
    EBox::debug("AceCount:  <$aceCount>");
    EBox::debug("Sbz2:      <$sbz2>");

    $self->decodeACL(substr($blob, $offset, $aclSize), $aceCount);
}

sub decodeDACL
{
    my ($self, $blob, $offset) = @_;

    EBox::debug("Decode DACL at offset <$offset>");
    my $revision;
    my $sbz1;
    my $aclSize;
    my $aceCount;
    my $sbz2;

    my $fmt = "\@$offset(C C S S S)";
    ($revision, $sbz1, $aclSize, $aceCount, $sbz2) = unpack($fmt, $blob);

    EBox::debug("Revision:  <$revision>");
    EBox::debug("Sbz1:      <$sbz1>");
    EBox::debug("AclSize:   <$aclSize>");
    EBox::debug("AceCount:  <$aceCount>");
    EBox::debug("Sbz2:      <$sbz2>");
}

# Method: decodeBlob
#
#   Decodes a binary blob containing a security descriptor
#
sub decodeBlob
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

    if ((not ($control & CONTROL_OD)) and ($offsetOwner != 0)) {
        my $ownerSID = $self->decodeSID($blob, $offsetOwner);
        $self->setOwnerSID($ownerSID);
    }

    if ((not ($control & CONTROL_GD)) and ($offsetGroup != 0)) {
        my $groupSID = $self->decodeSID($blob, $offsetGroup);
        $self->setGroupSID($groupSID);
    }

    if (($control & CONTROL_SP) and $offsetSACL != 0) {
        $self->decodeSACL($blob, $offsetSACL);
    }

    if (($control & CONTROL_DP) and $offsetDACL != 0) {
        $self->decodeDACL($blob, $offsetDACL);
    }
}

1;
