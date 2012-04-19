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

package EBox::LDB;

use strict;
use warnings;

use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::MissingArgument;

use Error qw( :try );
use File::Slurp qw( write_file read_file);

use constant SAM   => '/var/lib/samba/private/sam.ldb';
use constant IDMAP => '/var/lib/samba/private/idmap.ldb';

sub instance
{
    my $class = shift;
    my $self = {};
    bless ($self, $class);
    return $self;
}

# Method: rootDN
#
#   Returns the base DN of the domain
#
# Returns:
#
#   string - DN
#
sub rootDN
{
    my ($self) = @_;

    unless (defined $self->{rootDN}) {
        my $args = {'base' => "''",
                    'scope' => 'base',
                    'filter' => '(objectclass=*)',
                    'attrs' => 'namingContexts'};
        my $result = $self->search(SAM, $args);
        my $entry = @{$result}[0];
        my $attr = ($entry->attributes)[0];
        $self->{rootDN} = $entry->get_value($attr);
    }

    return defined ($self->{rootDN}) ? $self->{rootDN} : '';
}

# Method: search
#
#   Performs a search in a LDB file
#
# Parameters:
#
#   file - Path to the LDB file
#   args - Hash reference containig base, scope, filter and attrs
#
# Exceptions:
#
#   Internal - If there is an error during the search
#
sub search
{
    my ($self, $file, $params) = @_;

    unless (defined $file) {
        throw EBox::Exceptions::MissingArgument('file');
    }

    unless (defined $params) {
        $params = {};
    }

    unless (defined $params->{base}) {
        $params->{base} = $self->rootDN();
    }

    unless (defined $params->{attrs}) {
        $params->{attrs} = '';
    }

    if (defined $params->{filter}) {
        $params->{filter} = '(&' . $params->{filter} . '(!(isDeleted=TRUE)))';
    } else {
        $params->{filter} = '(&(objectClass=*)(!(isDeleted=TRUE)))';
    }

    unless (defined $params->{scope}) {
        $params->{scope} = 'sub';
    }

    my $cmd = "ldbsearch -H $file " .
              " -b '$params->{base}' " .
              " -s '$params->{scope}' " .
              " '$params->{filter}' " .
              $params->{attrs};
    my $ldif = EBox::Sudo::root($cmd);
    my $path = EBox::Config::tmp() . 'ldbsearch.ldif';
    write_file($path, $ldif);
    $ldif = Net::LDAP::LDIF->new($path, "r",
        encode => 'base64', onerror => 'undef' );

    my $results = [];
    while (not $ldif->eof()) {
        my $entry = $ldif->read_entry();
        if (not $ldif->error()) {
            push ($results, $entry);
        }
    }
    unlink $path;

    return $results;
}

sub modify
{
    my ($self, $file, $dn, $changes) = @_;

    unless (defined $file) {
        throw EBox::Exceptions::MissingArgument('file');
    }

    unless (defined $dn) {
        throw EBox::Exceptions::MissingArgument('dn');
    }

    my $additions = delete $changes->{add};
    my $deletions = delete $changes->{delete};
    my $replaces  = delete $changes->{replace};
    my $replacesB64  = delete $changes->{replaceB64};

    my $ldif = "dn: $dn\n" .
               "changetype: modify\n";

    foreach my $attr (keys %{$deletions}) {
        $ldif .= "delete: $attr\n";
        foreach my $val (@{$deletions->{$attr}}) {
            $ldif .= "$attr: $val\n";
        }
    }
    foreach my $attr (keys %{$additions}) {
        $ldif .= "add: $attr\n";
        $ldif .= "$attr: $additions->{$attr}\n";
    }
    foreach my $attr (keys %{$replaces}) {
        $ldif .= "replace: $attr\n";
        foreach my $value (@{$replaces->{$attr}}) {
            $ldif .= "$attr: $value\n";
        }
    }
    foreach my $attr (keys %{$replacesB64}) {
        $ldif .= "replace: $attr\n";
        foreach my $value (@{$replacesB64->{$attr}}) {
            $ldif .= "$attr\:: $value\n";
        }
    }
    my $path = EBox::Config::tmp() . 'ldbmodify.ldif';
    write_file($path, $ldif);

    EBox::Sudo::root("ldbmodify -H $file $path");
    unlink $path;
}

sub add
{
    my ($self, $file, $dn, $attrs) = @_;

    unless (defined $file) {
        throw EBox::Exceptions::MissingArgument('file');
    }

    unless (defined $dn) {
        throw EBox::Exceptions::MissingArgument('dn');
    }

    my $ldif = "dn: $dn\n".
               "changetype: add\n";
    foreach my $key (keys %{$attrs}) {
        $ldif .= "$key: $attrs->{$key}\n";
    }
    my $path = EBox::Config::tmp() . 'ldbadd.ldif';
    write_file($path, $ldif);

    EBox::Sudo::root("ldbadd -H $file $path");
    unlink $path;
}

sub delete
{
    my ($self, $file, $dn) = @_;

    unless (defined $file) {
        throw EBox::Exceptions::MissingArgument('file');
    }

    unless (defined $dn) {
        throw EBox::Exceptions::MissingArgument('dn');
    }

    my $ldif = "dn: $dn\n" .
               "changetype: delete\n";
    my $path = EBox::Config::tmp() . 'ldbdelete.ldif';
    write_file($path, $ldif);

    EBox::Sudo::root("ldbmodify -H $file $path");
    unlink $path;
}

#############################################################################
## LDB related functions                                                   ##
#############################################################################

# Method getIdByDN
#
#   Get samAccountName by object's DN
#
# Parameters:
#
#   dn - The DN of the object
#
# Returns:
#
#   The samAccountName of the object
#
sub getIdByDN
{
    my ($self, $dn) = @_;

    my $args = { base => $dn,
                 scope  => 'base',
                 filter => "(dn=$dn)",
                 attrs => 'sAMAccountName'};
    my $result = $self->search(SAM, $args);
    if (scalar @{$result} == 1) {
        my $entry = pop $result;
        my $value = $entry->get_value('sAMAccountName');
        return $value;
    } else {
        throw EBox::Exceptions::DataNotFound("DN '$dn' not found");
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

    my $args = { base => $self->rootDN(),
                 scope  => 'sub',
                 filter => "(sAMAccountName=$objectId)",
                 attrs => 'objectSid'};
    my $result = $self->search(SAM, $args);
    if (scalar @{$result} == 1) {
        my $entry = pop $result;
        my $value = $entry->get_value('objectSid');
        return $value;
    } else {
        throw EBox::Exceptions::DataNotFound("sAMAccountName '$objectId' not found");
    }
}

sub xidMapping
{
    my ($self, $id, $xid) = @_;

    # Search the SID and objectClass
    my $params = { filter => "(sAMAccountName=$id)",
                   base  => $self->rootDN(),
                   scope => 'sub',
                   attrs => 'objectSid objectClass' };
    my $samResult = $self->search(SAM, $params);
    unless (scalar @{$samResult} == 1) {
        throw EBox::Exceptions::DataNotFound("sAMAccountName '$id' not found");
    }
    my $samEntry = pop $samResult;
    my $objectSid = $samEntry->get_value('objectSid');

    # Search if it is already mapped
    my $dn = "CN=$objectSid";
    $params = { base => $dn,
                scope => 'base',
                attrs => 'xidNumber' };
    my $idmapResult = $self->search(IDMAP, $params);
    my $idmapEntry = pop $idmapResult;

    unless (defined $idmapEntry) {
        # Is it a user or a group?
        my @objectClass = $samEntry->get_value('objectClass');
        my %objectClass = map { $_ => 1 } @objectClass;

        $params = { cn => $objectSid,
                    objectClass => 'sidMap',
                    objectSid => $objectSid,
                    xidNumber => $xid,
                    distinguishedName => $dn };
        if (exists $objectClass{user}) {
            $params->{type} = 'ID_TYPE_UID';
        } elsif (exists $objectClass{group}) {
            $params->{type} = 'ID_TYPE_GID';
        } else {
            throw EBox::Exceptions::DataNotFound("objectClass not found");
        }

        EBox::debug("Creating xid mapping of '$id' to '$xid'");
        $self->add(IDMAP, $dn, $params);
    } else {
        # Replace the xid in idmap.ldb
        my $changes = { replace => { xidNumber => [ $xid ] } };

        EBox::debug("Updating xid mapping of '$id' to '$xid'");
        $self->modify(IDMAP, $dn, $changes);
    }
}

#sub syncGroupMembersLdapToLdb
#{
#    my ($self, $groupId, $sambaUsersToIgnore, $ldapUsersToIgnore) = @_;
#
#    my @sambaMembers = ();
#    my %sambaUsersToIgnore = map { $_ => 1 } @{$sambaUsersToIgnore};
#    foreach my $member (@{$self->getGroupMembers($groupId)}) {
#        my $memberId = $self->getIdByDN($member->{dn});
#        if (defined ($sambaUsersToIgnore)) {
#            push (@sambaMembers, $memberId) unless exists $sambaUsersToIgnore{$memberId};
#        } else {
#            push (@sambaMembers, $memberId);
#        }
#    }
#    @sambaMembers = sort (@sambaMembers);
#
#    my @ldapMembers = ();
#    my $usersModule = EBox::Global->modInstance('users');
#    my $group = new EBox::UsersAndGroups::Group(dn => $usersModule->groupDn($groupId));
#    my %ldapUsersToIgnore = map { $_ => 1 } @{$ldapUsersToIgnore};
#    foreach my $member (@{$group->users()}) {
#        my $memberId = $member->name();
#        if (defined ($ldapUsersToIgnore)) {
#            push (@ldapMembers, $memberId) unless exists $ldapUsersToIgnore{$memberId};
#        } else {
#            push (@ldapMembers, $memberId);
#        }
#    }
#    @ldapMembers = sort (@ldapMembers);
#
#    EBox::debug("Samba members @sambaMembers");
#    EBox::debug("LDAP members @ldapMembers");
#
#    my $diff = Array::Diff->diff (\@sambaMembers, \@ldapMembers);
#
#    # Add the missing members to the group
#    foreach my $memberId (@{$diff->added}) {
#        my $user = new EBox::UsersAndGroups::User(dn=>$usersModule->userDn($memberId));
#        my $username = $user->name();
#        EBox::debug("Adding user '$username' to LDAP group");
#        my $cmd = "samba-tool group addmembers '$groupId' '$username'";
#        EBox::Sudo::root($cmd);
#    }
#
#    # Remove the members
#    foreach my $memberId (@{$diff->deleted}) {
#        my $user = new EBox::UsersAndGroups::User(dn=>$usersModule->userDn($memberId));
#        my $username = $user->name();
#        EBox::debug("Removing user '$username' from LDAP group");
#        my $cmd = "samba-tool group removemembers '$groupId' '$username'";
#        EBox::Sudo::root($cmd);
#    }
#}

1;
