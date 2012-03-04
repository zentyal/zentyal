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

package EBox::Ldb;

use strict;
use warnings;

use EBox::Exceptions::DataNotFound;
use EBox::UsersAndGroups::Group;
use EBox::UsersAndGroups::User;

use LDB;
use Array::Diff;
use MIME::Base64;
use Encode qw(decode encode);

use constant LDB_DIR => '/var/lib/samba/private/sam.ldb.d';
use constant IDMAP_FILE => '/var/lib/samba/private/idmap.ldb';

sub new
{
    my $class = shift;
    my $self = {};
    bless ($self, $class);
    return $self;
}

# Method: rootDn
#
#   Returns the root DN of the domain (e.g. DC=yourdomain,DC=com)
#
# Returns:
#
#   string - DN
#
sub rootDn
{
    my ($self) = @_;

    if (!defined ($self->{dn})) {
        my $samba = EBox::Global->modInstance('samba');
        my $settings = $samba->model('GeneralSettings');
        my $realm = $settings->realmValue();
        my (@fields) = split (/\./, $realm);
        $self->{dn} = 'DC=' . join (',DC=', @fields);
    }
    return defined ($self->{dn}) ? $self->{dn} : '';
}

# Method: samdb
#
#   Returns the path to the samdb file
#
sub samdb
{
    my ($self) = @_;

    my $path = join ('/', LDB_DIR, uc ($self->rootDn())) . '.ldb';
    return $path;
}

# Method: clearConn
#
#   Clears DN cached value
#
sub clear
{
    my ($self) = @_;
    delete $self->{dn};
}

# Method: administratorDn
#
#   Returns the dn of the priviliged user
#
# Returns:
#
#   string - admindn
#
sub administratorDn {
    my ($self, $dn) = @_;
    unless (defined ($dn)) {
        $dn = $self->rootDn();
    }
    return 'CN=Administrator,CN=Users,' . $dn;
}

# Method: search
#
#       Performs a search in the LDB file
#
# Parameters:
#
#       args - arguments to pass to the LDB xs module
#
# Exceptions:
#
#       Internal - If there is an error during the search
#
sub search # (args)
{
    my ($self, $args) = @_;

    unless (exists $args->{url}) {
        $args->{url} = $self->samdb();
    }
    # Do not include deleted objects in searches
    if (exists $args->{filter}) {
        $args->{filter} = '(&' . $args->{filter} . '(!(isDeleted=TRUE)))';
    } else {
        $args->{filter} = '(!(isDeleted=TRUE))';
    }
    my $result = LDB::search($args);
    return $result;
}

sub modify
{
    my ($self, $url, $dn, $changes) = @_;

    my $str = "dn: $dn\nchangetype: modify\n";
    my $additions = $changes->{add};
    my $deletions = $changes->{delete};
    my $modifications = $changes->{modify};
    foreach my $attr (keys %{$additions}) {
        $str .= "add: $attr\n";
        $str .= "$attr: $additions->{$attr}\n";
    }
    foreach my $attr (keys %{$deletions}) {
        $str .= "delete: $attr\n";
        if (length ($deletions->{$attr}) > 0) {
            $str .= "$attr: $deletions->{$attr}\n";
        }
    }
    foreach my $attr (keys %{$modifications}) {
        $str .= "replace: $attr\n";
        $str .= "$attr: $modifications->{$attr}\n";
    }

    my $file = EBox::Config::tmp() . 'ldb.modify';
    open (FILE, ">$file");
    print FILE $str;
    close FILE;

    my $cmd = "ldbmodify -H $url $file";
    EBox::Sudo::root($cmd);
    #unlink $file;
}

sub add
{
    my ($self, $url, $dn, $attrs) = @_;

    my $str = "dn: $dn\n";
    foreach my $key (keys %{$attrs}) {
        $str .= "$key: $attrs->{$key}\n";
    }
    my $file = EBox::Config::tmp() . '/ldb.add';
    open (FILE, ">$file");
    print FILE $str;
    close FILE;

    my $cmd = "ldbadd -H $url $file";
    EBox::Sudo::root($cmd);
    unlink $file;
}

sub delete
{
    my ($self, $url, $dn) = @_;

    my $str = "dn: $dn\nchangetype: delete\n";
    my $file = EBox::Config::tmp() . '/ldb.delete';
    open (FILE, ">$file");
    print FILE $str;
    close FILE;

    my $cmd = "ldbmodify -H $url $file";
    EBox::Sudo::root($cmd);
    unlink $file;
}

#############################################################################
## Credentials related functions                                           ##
#############################################################################

# Method: decodeKerberos
#
#   Decode the KERB_STORED_CREDENTIAL struct. This struct
#   contains the hashes of the kerberos keys. Its format
#   is documented at:
#   http://msdn.microsoft.com/en-us/library/cc245503(v=prot.10).aspx
#
# Returns:
#
#   A hash reference with the kerberos keys
#
sub _decodeKerberos
{
    my ($self, $data) = @_;

    my $kerberosKeys = {};

    $data = pack('H*', $data); # from hex to binary
    my $format = 's x2 s s s s l a*';
    if (length ($data) > 16) {
        my ($revision, $nCredentials, $nOldCredentials, $saltLength, $maxSaltLength, $saltOffset) = unpack($format, $data);
        EBox::debug ("Kerberos info: revision '$revision', number of credentials '$nCredentials', " .
                     "number of old credentials '$nOldCredentials', salt length '$saltLength', " .
                     "salt max length '$maxSaltLength', salt offset '$saltOffset'");
        if ($revision == 3) {
            my ($saltValue) = unpack('@' . $saltOffset . 'a' . $maxSaltLength, $data);
            EBox::debug ("Salt length '$maxSaltLength', salt value '$saltValue'");

            my $offset = 16;
            for(my $i=0; $i<$nCredentials; $i++) {
                my ($keyType, $keyLength, $keyOffset) = unpack('@' . $offset . 'x8 l l l', $data);
                my ($keyValue) = unpack('@' . $keyOffset . 'a' . $keyLength, $data);
                $offset += 20;

                if ($keyType == 1) {
                    $kerberosKeys->{'dec-cbc-crc'} = $keyValue;
                }
                elsif ($keyType == 3) {
                    $kerberosKeys->{'des-cbc-md5'} = $keyValue;
                }
                EBox::debug ("Found kerberos key: type '$keyType', length '$keyLength', value '$keyValue'");
            }
        }
    }
    return $kerberosKeys;
}

# Method: decodeWDigest
#
#   Docode the WDIGEST_CREDENTIALS struct. This struct
#   contains 29 different hashes produced by combinations
#   of different elements including the sAMAccountName,
#   realm, host, etc. The format is documented at:
#   http://msdn.microsoft.com/en-us/library/cc245502(v=prot.10).aspx
#   The list of included hashes is documented at:
#   http://msdn.microsoft.com/en-us/library/cc245680(v=prot.10).aspx
#
# Returns:
#
#   An array reference containing the hashes
#
sub _decodeWDigest
{
    my ($self, $data) = @_;

    my $hashes = ();

    my $format = 'x4 a2 a2 x24 (a32)29';
    if (length ($data) == 960) {
        my ($version, $nHashes, @hashValues) = unpack($format, $data);
        $version = hex($version);
        $nHashes = hex($nHashes);
        EBox::debug ("WDigest info: version '$version', hash count '$nHashes'");
        if ($version == 1 and $nHashes == 29) {
            $hashes = \@hashValues;
        }
    }
    return $hashes;
}

# Method: decodeSupplementalCredentials
#
#   This method decodes the supplementalCredentials base64
#   encoded blob, called USER_PROPERTIES. The format of this
#   this struct is documented at:
#   http://msdn.microsoft.com/en-us/library/cc245500(v=prot.10).aspx
#   The USER_PROPERTIES contains various USER_PROPERTY structs,
#   documented at:
#   http://msdn.microsoft.com/en-us/library/cc245501(v=prot.10).aspx
#
# Returns:
#
#   A hash reference containing the different hashes
#   of the user credentials in different formats
#
sub _decodeSupplementalCredentials
{
    my ($self, $user, $blob) = @_;

    my $credentials = {};
    my $blobFormat = 'x4 L< x2 x2 x96 S< S< a*';
    if (length ($blob) > 112) {
        my ($blobLength, $blobSignature, $nProperties, $properties) = unpack ($blobFormat, $blob);
        # Check the signature. Its value must be 0x50
        if ($blobSignature == 0x50) {
            my $offset = 112;
            for (my $i=0; $i<$nProperties; $i++) {
                my ($propertyNameLength) = unpack('@' . $offset . 'S<', $blob);
                $offset += 2;

                my ($propertyValueLength) = unpack('@' . $offset . 'S<', $blob);
                $offset += 4; # 2 bytes + 2 bytes reserved

                my ($propertyName) = unpack('@' . $offset . 'a' . $propertyNameLength, $blob);
                $offset += $propertyNameLength;

                my ($propertyValue) = unpack('@' . $offset . 'a' . $propertyValueLength, $blob);
                $offset += $propertyValueLength;

                EBox::debug ("Found property '$propertyName'='$propertyValue'");
                if($propertyName eq encode('UTF-16LE', 'Primary:Kerberos')) {
                    $credentials->{'Primary:Kerberos'} = $self->_decodeKerberos($propertyValue);
                }
                elsif($propertyName eq encode('UTF-16LE', 'Primary:WDigest')) {
                    $credentials->{'Primary:WDigest'} = $self->_decodeWDigest($propertyValue);
                }
                elsif($propertyName eq encode('UTF-16LE', 'Primary:CLEARTEXT')) {
                    $credentials->{'Primary:CLEARTEXT'} = decode('UTF-16LE', pack ('H*', $propertyValue));
                }
            }
        } else {
            EBox::error ("Corrupted supplementalCredentials found on user $user");
        }
    } else {
        EBox::error ("Truncated supplementalCredentials found on user $user");
    }
    return $credentials;
}

# Method: getSambaCredentials
#
#   This method gets all the credentials stored in the
#   LDB for the user
#
# Parameters:
#
#   userID - The user ID (the sAMAccountName)
#
# Returns:
#
#   A hash reference containing all found credentials
#
sub getSambaCredentials
{
    my ($self, $userID) = @_;

    EBox::debug ("Getting samba credentials for user '$userID'");
    my $result = $self->search(
        {
            base => $self->rootDn(),
            scope  => 'sub',
            filter => "(sAMAccountName=$userID)",
            attrs => ['supplementalCredentials', 'unicodePwd'],
        });
    my $credentials = {};
    if (scalar (@{$result}) == 1) {
        my $entry = pop (@{$result});
        if (exists $entry->{supplementalCredentials}) {
            my $value = pop (@{$entry->{supplementalCredentials}});
            $credentials = $self->_decodeSupplementalCredentials($userID, $value);
        }
        if (exists $entry->{unicodePwd}) {
            my $value = pop (@{$entry->{unicodePwd}});
            $credentials->{'unicodePwd'} = $value;
        }
    } else {
        throw EBox::Exceptions::DataNotFound("User '$userID' not found");
    }
    return $credentials;
}

#############################################################################
## LDB related functions                                                   ##
#############################################################################

# Method getIDBySid
#
#   Get sAMAccountName by object's SID
#
# Parameters:
#
#   objectSid - The SID of the object
#
# Returns:
#
#   The sAMAccountName of the object
#
sub getIDBySid
{
    my ($self, $objectSid) = @_;

    my $result = $self->search({
            base => $self->rootDn(),
            scope  => 'sub',
            filter => "(objectSid=$objectSid)",
            attrs => ['sAMAccountName']});
    if (scalar (@{$result}) == 1) {
        my $entry = pop (@{$result});
        my $value = pop (@{$entry->{'sAMAccountName'}});
        return $value;
    } else {
        throw EBox::Exceptions::DataNotFound("SID '$objectSid' not found");
    }
}

# Method getSidById
#
#   Get SID by object's sAMAccountName
#
# Parameters:
#
#   id - The ID of the object
#
# Returns:
#
#   The SID of the object
#
sub getSidById
{
    my ($self, $objectId) = @_;

    my $result = $self->search({
            base => $self->rootDn(),
            scope  => 'sub',
            filter => "(sAMAccountName=$objectId)",
            attrs => ['objectSid']});
    if (scalar (@{$result}) == 1) {
        my $entry = pop (@{$result});
        my $value = pop (@{$entry->{'objectSid'}});
        return $value;
    } else {
        throw EBox::Exceptions::DataNotFound("sAMAccountName '$objectId' not found");
    }
}

# Method: getDNByID
#
#   Get DN by sAMAccountName
#
# Parameters:
#
#   ID - The object's ID
#
# Returns:
#
#   The DN of the object
#
sub getDNByID
{
    my ($self, $ID) = @_;

    my $result = $self->search({
            base => $self->rootDn(),
            scope  => 'sub',
            filter => "(sAMAccountName=$ID)",
            attrs => ['distinguishedName']});
    if (scalar (@{$result}) == 1) {
        my $entry = pop (@{$result});
        my $value = pop (@{$entry->{'distinguishedName'}});
        return $value;
    } else {
        throw EBox::Exceptions::DataNotFound("sAMAccountName '$ID' not found");
    }
}

# Method: getIdByDn
#
#   Get sAMAccountName by DN
#
# Parameters:
#
#   DN - The object's DN
#
# Returns:
#
#   The ID of the object
#
sub getIdByDN
{
    my ($self, $DN) = @_;

    my $result = $self->search({
            base => $self->rootDn(),
            scope  => 'sub',
            filter => "(distinguishedName=$DN)",
            attrs => ['sAMAccountName']}
            );
    if (scalar (@{$result}) == 1) {
        my $entry = pop (@{$result});
        my $value = pop (@{$entry->{'sAMAccountName'}});
        return $value;
    } else {
        throw EBox::Exceptions::DataNotFound("DN '$DN' not found");
    }
}

# Method: getUsers
#
#   This method get all users stored in the LDB
#
# Parameters:
#
#   usersToIgnore (optional) - list of users to ignore
#   system (optional) - include system users in the result
#
# Returns:
#
#   A hash referente containing all found entries
#
sub getUsers
{
    my ($self, $usersToIgnore, $system) = @_;

    my $filter = '(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=0x00000200))';
    if (defined $system) {
        $filter = '(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=0x00000200)(!(IsCriticalSystemObject=TRUE)))';
    }
    my $users = {};
    my $result = $self->search({
            base => $self->rootDn(),
            scope  => 'sub',
            filter => $filter});
    if (defined $usersToIgnore) {
        my %usersToIgnore = map { $_ => 1 } @{$usersToIgnore};
        foreach my $entry (@{$result}) {
            my $entryId = pop (@{$entry->{sAMAccountName}});
            next unless defined ($entryId);
            unless (exists $usersToIgnore{$entryId}) {
                $users->{$entryId} = $entry;
            }
        }
    } else {
        foreach my $entry (@{$result}) {
            my $entryId = pop (@{$entry->{sAMAccountName}});
            next unless defined ($entryId);
            $users->{$entryId} = $entry;
        }
    }
    return $users;
}

# Method: getGroups
#
#   This method get all groups stored in the LDB
#
# Parameters:
#
#   groupsToIgnore (optional) - reference to a list containing
#       the list of users to ignore
#
# Returns:
#
#   A hash referente containing the found entries
#
sub getGroups
{
    my ($self, $groupsToIgnore, $system) = @_;

    my $filter = '(&(objectClass=group)(groupType:1.2.840.113556.1.4.803:=0x0000002))';
    if (defined $system) {
        $filter = '(&(objectClass=group)(groupType:1.2.840.113556.1.4.803:=0x0000002)(!(isCriticalSystemObject=TRUE)))';
    }
    my $groups = {};
    my $result = $self->search({
            base => $self->rootDn(),
            scope  => 'sub',
            filter => $filter,
        });
    if (defined $groupsToIgnore) {
        my %groupsToIgnore = map { $_ => 1 } @{$groupsToIgnore};
        foreach my $entry (@{$result}) {
            my $entryId = pop (@{$entry->{sAMAccountName}});
            next unless defined ($entryId);
            unless (exists $groupsToIgnore{$entryId}) {
                $groups->{$entryId} = $entry;
            }
        }
    } else {
        foreach my $entry (@{$result}) {
            my $entryId = pop (@{$entry->{sAMAccountName}});
            next unless defined ($entryId);
            $groups->{$entryId} = $entry;
        }
    }
    return $groups;
}

sub xidMapping
{
    my ($self, $id, $xid) = @_;

    # Get the object SID
    my $objectSid = $self->getSidById($id);
    unless (defined $objectSid) {
        throw EBox::Exceptions::DataNotFound("Couldn't set mapping: $id not found");
    }

    # Search if it is already mapped
    my $dn = "CN=$objectSid";
    my $result = $self->search({
        url => IDMAP_FILE,
        filter => "(dn=$dn)",
        });
    if (scalar (@{$result}) == 0) {
        # Is it a user or a group?
        $result = $self->search({
            filter => "(sAMAccountName=$id)",
            attrs => ['objectClass'],
        });
        if (scalar (@{$result}) == 1) {
            my $class = undef;
            my $entry = pop (@{$result});
            foreach my $value (@{$entry->{objectClass}}) {
                if ($value == 'user') {
                    $class = 'ID_TYPE_UID';
                    last;
                } elsif ($value == 'group') {
                    $class = 'ID_TYPE_GID';
                    last;
                } else {
                    next;
                }
            }
            # Add the xid to idmap.ldb
            my $attrs = {
                cn => $objectSid,
                objectClass => 'sidMap',
                objectSid => $objectSid,
                type => $class,
                xidNumber => $xid,
                distinguishedName => $dn,
            };
            EBox::debug("Creating xid mapping of '$id' to '$xid'");
            $self->add(IDMAP_FILE, $dn, $attrs);
        } else {
            throw EBox::Exceptions::DataNotFound("Couldn't get objectClass for '$id'");
        }
    } else {
        # Replace the xid in idmap.ldb
        my $changes = {
            modify => {
                xidNumber => $xid,
            },
        };
        EBox::debug("Updating xid mapping of '$id' to '$xid'");
        $self->modify(IDMAP_FILE, $dn, $changes);
    }
}

# Method: getGroupsOfUser
#
#   Return the groups ID that the user belongs to
#
# Parameters:
#
#   userID - the user ID
#
# Returns:
#
#   A list reference containing the groups ID
#
sub getGroupsOfUser
{
    my ($self, $userID) = @_;

    my $result = $self->search({
        filter => "(&(sAMAccountName=$userID)(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=0x00000200))",
        attrs  => ['memberOf'],
    });
    my $groups = [];
    if (scalar @{$result} == 1) {
        my $entry = pop (@{$result});
        foreach my $val (@{$entry->{memberOf}}) {
            my $mem = {};
            my (@fields) = split (/;/, $val);
            foreach my $field (@fields) {
                if ($field =~ /^<.+>$/) {
                    $field =~ s/(<|>)//g;
                    my ($key, $value) = split (/=/, $field);
                    $key = lc ($key);
                    $mem->{$key} = $value;
                } else {
                    $mem->{dn} = $field;
                }
            }
            push (@{$groups}, $mem);
        }
    } else {
        throw EBox::Exceptions::DataNotFound("User '$userID' not found");
    }

    return $groups;
}

# Method: getGroupMembers
#
#   Return the users ID of the group members
#
# Parameters:
#
#   groupID - the group ID
#
# Returns:
#
#   A list reference containing the members ID
#
sub getGroupMembers
{
    my ($self, $groupID) = @_;

    my $result = $self->search({
        filter => "(&(sAMAccountName=$groupID)(objectClass=group)(groupType:1.2.840.113556.1.4.803:=0x0000002))",
        attrs => ['distinguishedName', 'member'],
    });
    my $members = [];
    if (scalar (@{$result}) == 1) {
        my $entry = pop (@{$result});
        if (exists $entry->{member}) {
            foreach my $val (@{$entry->{member}}) {
                my $mem = {};
                my (@fields) = split (/;/, $val);
                foreach my $field (@fields) {
                    if ($field =~ /^<.+>$/) {
                        $field =~ s/(<|>)//g;
                        my ($key, $value) = split (/=/, $field);
                        $key = lc ($key);
                        $mem->{$key} = $value;
                    } else {
                        $mem->{dn} = $field;
                    }
                }
                # Check the removed flag
                if ($mem->{rmd_flags} == 0) {
                    push (@{$members}, $mem);
                }
            }
        }
    } else {
        throw EBox::Exceptions::DataNotFound("Group '$groupID' not found");
    }

    return $members;
}

sub syncGroupMembersLdapToLdb
{
    my ($self, $groupId, $sambaUsersToIgnore, $ldapUsersToIgnore) = @_;

    my @sambaMembers = ();
    my %sambaUsersToIgnore = map { $_ => 1 } @{$sambaUsersToIgnore};
    foreach my $member (@{$self->getGroupMembers($groupId)}) {
        my $memberId = $self->getIdByDN($member->{dn});
        if (defined ($sambaUsersToIgnore)) {
            push (@sambaMembers, $memberId) unless exists $sambaUsersToIgnore{$memberId};
        } else {
            push (@sambaMembers, $memberId);
        }
    }
    @sambaMembers = sort (@sambaMembers);

    my @ldapMembers = ();
    my $usersModule = EBox::Global->modInstance('users');
    my $group = new EBox::UsersAndGroups::Group(dn => $usersModule->groupDn($groupId));
    my %ldapUsersToIgnore = map { $_ => 1 } @{$ldapUsersToIgnore};
    foreach my $member (@{$group->users()}) {
        my $memberId = $member->name();
        if (defined ($ldapUsersToIgnore)) {
            push (@ldapMembers, $memberId) unless exists $ldapUsersToIgnore{$memberId};
        } else {
            push (@ldapMembers, $memberId);
        }
    }
    @ldapMembers = sort (@ldapMembers);

    EBox::debug("Samba members @sambaMembers");
    EBox::debug("LDAP members @ldapMembers");

    my $diff = Array::Diff->diff (\@sambaMembers, \@ldapMembers);

    # Add the missing members to the group
    foreach my $memberId (@{$diff->added}) {
        my $user = new EBox::UsersAndGroups::User(dn=>$usersModule->userDn($memberId));
        EBox::debug('Adding user ' . $user->name() . ' to LDAP group');
        my $cmd = "samba-tool group addmembers $groupId " . $user->name();
        EBox::Sudo::root($cmd);
    }

    # Remove the members
    foreach my $memberId (@{$diff->deleted}) {
        my $user = new EBox::UsersAndGroups::User(dn=>$usersModule->userDn($memberId));
        EBox::debug('Removing user ' . $user->name() . ' from LDAP group');
        my $cmd = "samba-tool group removemembers $groupId " . $user->name();
        EBox::Sudo::root($cmd);
    }
}

sub syncGroupMembersLdbToLdap
{
    my ($self, $groupId, $sambaUsersToIgnore, $ldapUsersToIgnore) = @_;

    my @sambaMembers = ();
    my %sambaUsersToIgnore = map { $_ => 1 } @{$sambaUsersToIgnore};
    foreach my $member (@{$self->getGroupMembers($groupId)}) {
        my $memberId = $self->getIdByDN($member->{dn});
        if (defined ($sambaUsersToIgnore)) {
            push (@sambaMembers, $memberId) unless exists $sambaUsersToIgnore{$memberId};
        } else {
            push (@sambaMembers, $memberId);
        }
    }
    @sambaMembers = sort (@sambaMembers);

    my @ldapMembers = ();
    my $usersModule = EBox::Global->modInstance('users');
    my $group = new EBox::UsersAndGroups::Group(dn => $usersModule->groupDn($groupId));
    my %ldapUsersToIgnore = map { $_ => 1 } @{$ldapUsersToIgnore};
    foreach my $member (@{$group->users()}) {
        my $memberId = $member->name();
        if (defined ($ldapUsersToIgnore)) {
            push (@ldapMembers, $memberId) unless exists $ldapUsersToIgnore{$memberId};
        } else {
            push (@ldapMembers, $memberId);
        }
    }
    @ldapMembers = sort (@ldapMembers);

    EBox::debug("Samba members @sambaMembers");
    EBox::debug("LDAP members @ldapMembers");

    my $diff = Array::Diff->diff (\@ldapMembers, \@sambaMembers);

    # Add the missing members to the group
    foreach my $memberId (@{$diff->added}) {
        my $user = new EBox::UsersAndGroups::User(dn=>$usersModule->userDn($memberId));
        EBox::debug('Adding user ' . $user->name() . ' to LDAP group');
        $group->addMember($user, 1);
    }

    # Remove the members
    foreach my $memberId (@{$diff->deleted}) {
        my $user = new EBox::UsersAndGroups::User(dn=>$usersModule->userDn($memberId));
        EBox::debug('Removing user ' . $user->name() . ' from LDAP group');
        $group->removeMember($user, 1);
    }
    $group->save(['samba']);
}

1;
