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

# Class: EBox::Samba::AccessControlEntry
#
#   This is a helper class to generate ACE entries (an entry in an access control list).
#   An ACE contains a set of access rights and a security identifier (SID) that identifies
#   a trustee for whom the rights are allowed, denied, or audited.
#
#   Documentation:
#   http://msdn.microsoft.com/en-us/library/windows/desktop/aa374928%28v=vs.85%29.aspx
#
package EBox::Samba::AccessControlEntry;

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidArgument;
use EBox::Exceptions::NotImplemented;

use Error qw(:try);

#
# ACE types valid tokens
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
    'ML'  => 'MANDATORY_LABEL',
    'XA'  => 'CALLBACK_ACCESS_ALLOWED',        # Windows Vista and Windows Server 2003:  Not available.
    'XD'  => 'CALLBACK_ACCESS_DENIED',         # Windows Vista and Windows Server 2003:  Not available.
    'RA'  => 'RESOURCE_ATTRIBUTE',             # Windows Server 2008 R2, Windows 7, Windows Server 2008, Windows Vista, and Windows Server 2003:  Not available.
    'SP'  => 'SCOPED_POLICY_ID',               # Windows Server 2008 R2, Windows 7, Windows Server 2008, Windows Vista, and Windows Server 2003:  Not available.
    'XU'  => 'CALLBACK_AUDIT',                 # Windows Server 2008 R2, Windows 7, Windows Server 2008, Windows Vista, and Windows Server 2003:  Not available.
    'ZA'  => 'CALLBACK_OBJECT_ACCESS_ALLOWED', # Windows Server 2008 R2, Windows 7, Windows Server 2008, Windows Vista, and Windows Server 2003:  Not available.
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

    # Registry Access Rights
    KA => "KEY_ALL_ACCESS",
    KR => "KEY_READ",
    KW => "KEY_WRITE",
    KX => "KEY_EXECUTE",

    # Mandatory Label Rights
    MR => 'LABEL_NO_READ_UP',
    MW => 'LABEL_NO_WRITE_UP',
    NX => 'LABEL_NO_EXECUTE_UP',
};

#
# ACE or security descriptor valid SID tokens
#
my $sidStrings = {
    AN  =>  'ANONYMOUS',                        # Anonymous logon. The corresponding RID is SECURITY_ANONYMOUS_LOGON_RID.
    AO  =>  'ACCOUNT_OPERATORS',                # Account operators. The corresponding RID is DOMAIN_ALIAS_RID_ACCOUNT_OPS.
    AU  =>  'AUTHENTICATED_USERS',              # Authenticated users. The corresponding RID is SECURITY_AUTHENTICATED_USER_RID.
    BA  =>  'BUILTIN_ADMINISTRATORS',           # Built-in administrators. The corresponding RID is DOMAIN_ALIAS_RID_ADMINS.
    BG  =>  'BUILTIN_GUESTS',                   # Built-in guests. The corresponding RID is DOMAIN_ALIAS_RID_GUESTS.
    BO  =>  'BACKUP_OPERATORS',                 # Backup operators. The corresponding RID is DOMAIN_ALIAS_RID_BACKUP_OPS.
    BU  =>  'BUILTIN_USERS',                    # Built-in users. The corresponding RID is DOMAIN_ALIAS_RID_USERS.
    CA  =>  'CERT_SERV_ADMINISTRATORS',         # Certificate publishers. The corresponding RID is DOMAIN_GROUP_RID_CERT_ADMINS.
    CD  =>  'CERTSVC_DCOM_ACCESS',              # Users who can connect to certification authorities using Distributed Component Object Model (DCOM).
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
    HI  =>  'ML_HIGH',                          # High integrity level. The corresponding RID is SECURITY_MANDATORY_HIGH_RID.
    IU  =>  'INTERACTIVE',                      # Interactively logged-on user. This is a group identifier added to the token of a
                                                # process when it was logged on interactively. The corresponding logon type is LOGON32_LOGON_INTERACTIVE.
                                                # The corresponding RID is SECURITY_INTERACTIVE_RID.
    LA  =>  'LOCAL_ADMIN',                      # Local administrator. The corresponding RID is DOMAIN_USER_RID_ADMIN.
    LG  =>  'LOCAL_GUEST',                      # Local guest. The corresponding RID is DOMAIN_USER_RID_GUEST.
    LS  =>  'LOCAL_SERVICE',                    # Local service account. The corresponding RID is SECURITY_LOCAL_SERVICE_RID.
    LW  =>  'ML_LOW',                           # Low integrity level. The corresponding RID is SECURITY_MANDATORY_LOW_RID.
    ME  =>  'MLMEDIUM',                         # Medium integrity level. The corresponding RID is SECURITY_MANDATORY_MEDIUM_RID.
    MU  =>  'PERFMON_USERS',                    # Performance Monitor users.
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
    RS  =>  'RAS_SERVERS RAS',                  # servers group. The corresponding RID is DOMAIN_ALIAS_RID_RAS_SERVERS.
    RU  =>  'ALIAS_PREW2KCOMPACC',              # Alias to grant permissions to accounts that use applications compatible with operating systems previous to Windows 2000.
                                                # The corresponding RID is DOMAIN_ALIAS_RID_PREW2KCOMPACCESS.
    SA  =>  'SCHEMA_ADMINISTRATORS',            # Schema administrators. The corresponding RID is DOMAIN_GROUP_RID_SCHEMA_ADMINS.
    SI  =>  'ML_SYSTEM',                        # System integrity level. The corresponding RID is SECURITY_MANDATORY_SYSTEM_RID.
    SO  =>  'SERVER_OPERATORS',                 # Server operators. The corresponding RID is DOMAIN_ALIAS_RID_SYSTEM_OPS.
    SU  =>  'SERVICE',                          # Service logon user. This is a group identifier added to the token of a process when it was logged as a service.
                                                # The corresponding logon type is LOGON32_LOGON_SERVICE. The corresponding RID is SECURITY_SERVICE_RID.
    SY  =>  'LOCAL_SYSTEM',                     # Local system. The corresponding RID is SECURITY_LOCAL_SYSTEM_RID.
    WD  =>  'EVERYONE',                         # Everyone. The corresponding RID is SECURITY_WORLD_RID
};

sub new
{
    # TODO Add contructor parameters

    my ($class, %params) = @_;

    my $self = {};

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
    my ($self, @flags) = @_;

    unless (defined @flags and scalar @flags) {
        throw EBox::Exceptions::MissingArgument('flags');
    }
    foreach my $flag (@flags) {
        unless (exists $aceFlags->{$flag}) {
            throw EBox::Exceptions::InvalidArgument('ACE flag', $flag);
        }
    }
    $self->{flags} = join ('', @flags);
}

# Method: setRights
#
#   Sets the string that indicates the access rights controlled by the ACE.
#   This string is a concatenation of one or more keys of the hash $aceRights
#
sub setRights
{
    my ($self, @rights) = @_;

    unless (defined @rights and scalar @rights) {
        throw EBox::Exceptions::MissingArgument('rights');
    }
    foreach my $token (@rights) {
        unless (exists $aceRights->{$token}) {
            throw EBox::Exceptions::InvalidArgument('ACE Access Right', $token);
        }
    }
    $self->{rights} = join ('', @rights);
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
        $string .= ';';
    }
    if (defined $self->{inheritObjectGUID}) {
        $string .= $self->{inheritObjectGUID};
        $string .= ';';
    }
    $string .= $self->{objectSID};
    $string .= ';';

    return $string;
}

1;
