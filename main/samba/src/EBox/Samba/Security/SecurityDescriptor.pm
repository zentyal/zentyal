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

    unless (defined $params{ownerSID}) {
        throw EBox::Exceptions::MissingArgument('ownerSID');
    }
    unless (defined $params{groupSID}) {
        throw EBox::Exceptions::MisssinArgument('groupSID');
    }

    my $self = {};
    bless ($self, $class);

    $self->setOwnerSID($params{ownerSID});
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

1;
