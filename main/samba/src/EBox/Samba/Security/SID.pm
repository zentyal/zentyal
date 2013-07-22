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

# Class: EBox::Samba::Security::SID
#
#   A security identifier (SID) uniquely identifies a security principal.
#   Each security principal has a unique SID that is issued by a security
#   agent. The agent can be a Microsoft Windows® local system or domain.
#   The agent generates the SID when the security principal is created.
#   The SID can be represented as a character string or as a structure.
#   When represented as strings, for example in documentation or logs,
#   SIDs are expressed as follows:
#   S-1-IdentifierAuthority-SubAuthority1-SubAuthority2-...-SubAuthorityn
#   The top-level issuer is the authority. Each issuer specifies, in an
#   implementation-specific manner, how many integers identify the next issuer.
#   A newly created account store is assigned a 96-bit identifier (a
#   cryptographic strength (pseudo) random number).
#   A newly created security principal in an account store is assigned a
#   32-bit identifier that is unique within the store.
#   The last item in the series of SubAuthority values is known as the
#   relative identifier (RID).
#   Differences in the RID are what distinguish the different SIDs generated
#   within a domain.
#
package EBox::Samba::Security::SID;

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Internal;

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

    unless (defined $params{blob} or defined $params{sid}) {
        throw EBox::Exceptions::MissingArgument('blob | sid)');
    }

    if (defined $params{blob}) {
        $self->_decode($params{blob}, $params{blobOffset});
    }

    return $self;
}

sub asString
{
    my ($self) = @_;

    # TODO Implement
    return '';
}

# Method: _decode
#
#   Decodes a SID in binary format
#
# Arguments:
#
#   blob - The binary blob
#   blobOffset - (optional) The offset inside the blob where the SID structure
#                start
#
# Documentation:
#
#   [MS-DTYP] Section 2.4.2.2
#
sub _decode
{
    my ($self, $blob, $offset) = @_;

    $offset = 0 unless defined $offset;

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

    unless ($revision == 0x01) {
        throw EBox::Exceptions::Internal(
            "Wrong SID revision (was $revision, expected 0x01)");
    }

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

1;
