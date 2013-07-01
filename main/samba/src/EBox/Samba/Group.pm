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
# Class: EBox::Samba::Group
#
#   Samba group, stored in samba LDAP
#

package EBox::Samba::Group;
use base 'EBox::Samba::LdbObject';

use EBox::Global;
use EBox::Gettext;

use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;

use EBox::Users::User;
use EBox::Users::Group;

use EBox::Samba::Contact;

use Perl6::Junction qw(any);
use Error qw(:try);

use constant MAXGROUPLENGTH     => 128;
use constant GROUPTYPESYSTEM    => 0x00000001;
use constant GROUPTYPEGLOBAL    => 0x00000002;
use constant GROUPTYPELOCAL     => 0x00000004;
use constant GROUPTYPEUNIVERSAL => 0x00000008;
use constant GROUPTYPEAPPBASIC  => 0x00000010;
use constant GROUPTYPEAPPQUERY  => 0x00000020;
use constant GROUPTYPESECURITY  => 0x80000000;



sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless ($self, $class);
    return $self;
}

sub mainObjectClass
{
    return 'group';
}


# Method: removeAllMembers
#
#   Remove all members in the group
#
sub removeAllMembers
{
    my ($self, $lazy) = @_;
    $self->delete('member');
}

# Method: addMember
#
#   Adds the given user as a member
#
# Parameters:
#
#   user - User object
#
sub addMember
{
    my ($self, $user, $lazy) = @_;

    my @members = $self->get('member');

    # return if user already in the group
    foreach my $dn (@members) {
        if (lc ($dn) eq lc ($user->dn())) {
            return;
        }
    }

    $self->add('member', $user->dn(), $lazy);
}

# Method: removeMember
#
#   Removes the given user as a member
#
# Parameters:
#
#   user - User object
#
sub removeMember
{
    my ($self, $user, $lazy) = @_;

    my @members;
    foreach my $dn ($self->get('member')) {
        push (@members, $dn) if (lc ($dn) ne lc ($user->dn()));
    }

    $self->deleteValues('member', [$user->dn()], $lazy);
}

# Method: members
#
#   Return the list of members for this group
#
# Returns:
#
#   arrary ref of members (EBox::Samba::User or EBox::Samba::Group)
#
sub members
{
    my ($self) = @_;

    my $members = [];
    my @membersDN = $self->get('member');
    foreach my $memberDN (@membersDN) {
        my $obj = new EBox::Samba::LdbObject(dn => $memberDN);
        my @class = $obj->get('objectClass');
        if ('user' eq any @class) {
            push (@{$members}, new EBox::Samba::User(dn => $memberDN));
            next;
        }
        if ('group' eq any @class) {
            push (@{$members}, new EBox::Samba::Group(dn => $memberDN));
            next;
        }
        if ('contact' eq any @class) {
            push (@{$members}, new EBox::Samba::Contact(dn => $memberDN));
            next;
        }

        # Unknown member type
        my $dn = $self->dn();
        EBox::warn("Unknown group member type ($memberDN) found on group $dn");
    }

    return $members;
}

sub setupGidMapping
{
    my ($self, $gidNumber) = @_;

    # NOTE Samba4 beta2 support rfc2307, reading uidNumber from ldap instead idmap.ldb, but
    # it is not working when the user init session as DOMAIN/user but user@domain.com
    # FIXME Remove this when fixed
    my $type = $self->_ldap->idmap->TYPE_GID();
    $self->_ldap->idmap->setupNameMapping($self->sid(), $type, $gidNumber);
}

# Method: create
#
#   Adds a new Samba group.
#
# Parameters:
#
#   name   - Group name.
#   params - Hash reference with the following fields:
#       description     - Group's description.
#       parent          - Parent container that will hold this new Group.
#       isSecurityGroup - If true it creates a security group, otherwise creates a distribution group. By default true.
#       gidNumber       - The gid number to use for this group. If not defined it will auto assigned by the system.
# TODO: Add OU.
#
sub create
{
    my ($self, $name, $params) = @_;

    $params->{parent} or
        throw EBox::Exceptions::MissingArgument('parent');
    $params->{parent}->isContainer() or
        throw EBox::Exceptions::InvalidData(
            data => 'parent', value => $params->{parent}->dn());


    my $isSecurityGroup = $params->{isSecurityGroup};
    # TODO Is the group added to the default OU?
    my $baseDn = $self->_ldap->dn();
    my $dn = "CN=$name," . $params->{parent}->dn();

    $self->_checkAccountName($name, MAXGROUPLENGTH);
    $self->_checkAccountNotExists($name);

    # TODO: We may want to support more than global groups!
    my $groupType = GROUPTYPEGLOBAL;
    my $attr = [];
    push ($attr, cn => $name);
    push ($attr, objectClass    => ['top', 'group', 'posixAccount']);
    push ($attr, sAMAccountName    => "$name");
    push ($attr, description       => $params->{description}) if defined $params->{description};
    if ($isSecurityGroup) {
        push ($attr, gidNumber         => $params->{gidNumber}) if defined $params->{gidNumber};
        $groupType |= GROUPTYPESECURITY;
    }

    push ($attr, groupType         => $groupType);

    # Add the entry
    my $result = $self->_ldap->add($dn, { attrs => $attr });
EBox::info("added");
    my $createdGroup = new EBox::Samba::Group(dn => $dn);

    # Setup the gid mapping
    $createdGroup->setupGidMapping($params->{gidNumber}) if defined $params->{gidNumber};

    return $createdGroup;
}

sub addToZentyal
{
    my ($self, $ou) = @_;
    $ou or throw EBox::Exceptions::MissingArgument('ou');

    my $name      = $self->get('samAccountName');
    my $gidNumber = $self->get('gidNumber');

    my @params = (
        name => $name,
        description =>  $self->get('description'),
        parent => $ou,
        ignoreMods  => ['samba'],
    );
    EBox::info("Adding samba group '$name' to Zentyal");
    my $zentyalGroup = undef;

    if (not $gidNumber) {
        $gidNumber = $self->getXidNumberFromRID();
        $gidNumber or
            throw EBox::Exceptions::Internal("Could not get gidNumber for group $name");
        $self->set('gidNumber', $gidNumber);
    }

    push @params, gidNumber => $gidNumber;
    $self->setupGidMapping($gidNumber);

    push @params, isSecurityGroup => $self->isSecurityGroup();
    push @params, isSystemGroup   => 0;
    $zentyalGroup = EBox::Users::Group->create(@params);
    $zentyalGroup->exists() or throw EBox::Exceptions::Internal("Error adding samba group '$name' to Zentyal");

    $self->_membersToZentyal($zentyalGroup);
}

sub updateZentyal
{
    my ($self) = @_;

    my $gid = $self->get('samAccountName');
    EBox::info("Updating zentyal group '$gid'");

    my $zentyalGroup = undef;

    my $desc = $self->get('description');

    $zentyalGroup = new EBox::Users::Group(gid => $gid);
    $zentyalGroup->exists() or
        throw EBox::Exceptions::Internal("Zentyal group '$gid' does not exist");

    $zentyalGroup->setIgnoredModules(['samba']);
    $zentyalGroup->setSecurityGroup($self->isSecurityGroup(), 1);
    $zentyalGroup->set('description', $desc, 1);
    $zentyalGroup->save();

    $self->_membersToZentyal($zentyalGroup);
}

sub _membersToZentyal
{
    my ($self, $zentyalGroup) = @_;

    return unless (defined $zentyalGroup and $zentyalGroup->exists());

    my $gid = $self->get('samAccountName');
    my $sambaMembersList = $self->members();
    my $zentyalMembersList = $zentyalGroup->users();

    my %zentyalMembers = map { $_->get('uid') => $_ } @{$zentyalMembersList};
    my %sambaMembers;
    foreach my $sambaMember (@{$sambaMembersList}) {
        if ($sambaMember->isa('EBox::Samba::Group')) {
            my $dn = $sambaMember->dn();
            EBox::warn("Member '$dn' is a nested group, not supported!");
            next;
        }
        if ($sambaMember->isa('EBox::Samba::User')) {
            my $samAccountName = $sambaMember->get('samAccountName');
            if (defined $samAccountName) {
                $sambaMembers{$samAccountName} = $sambaMember;
                next;
            }
            my $dn = $sambaMember->dn();
            EBox::warn("Member '$dn' does not seem to be a user, skipped");
        }
        if ($sambaMember->isa('EBox::Samba::Contact') and
            EBox::Config::boolean('treat_contacts_as_users')) {
            my $mail = $sambaMember->get('mail');
            $mail =~ s/@.*$//;
            my $aUser = new EBox::Samba::User(samAccountName => $mail);
            if ($aUser->exists()) {
                $sambaMembers{$mail} = $aUser;
                next;
            }
        }
        my $dn = $sambaMember->dn();
        EBox::warn("Unexpected member type ($dn)");
    }

    foreach my $memberName (keys %zentyalMembers) {
        unless (exists $sambaMembers{$memberName}) {
            EBox::info("Removing member '$memberName' from Zentyal group '$gid'");
            try {
                $zentyalGroup->removeMember($zentyalMembers{$memberName}, 1);
            } otherwise {
                my ($error) = @_;
                EBox::error("Error removing user '$memberName' for group '$gid': $error");
            };
         }
    }

    foreach my $memberName (keys %sambaMembers) {
        unless (exists $zentyalMembers{$memberName}) {
            EBox::info("Adding member '$memberName' to Zentyal group '$gid'");
            my $zentyalUser = new EBox::Users::User(uid => $memberName);
            if (not $zentyalUser->exists()) {
                EBox::error("Cannot add user '$memberName' to group '$gid' because the user does not exist");
                next;
            }
            try {
                $zentyalGroup->addMember($zentyalUser, 1);
            } otherwise {
                my ($error) = @_;
                EBox::error("Error adding user '$memberName' for group '$gid': $error");
            };
        }
    }

    $zentyalGroup->setIgnoredModules(['samba']);
    $zentyalGroup->save();
}

sub _checkAccountName
{
    my ($self, $name, $maxLength) = @_;
    $self->SUPER::_checkAccountName($name, $maxLength);
    if ($name =~ m/^[[:space:]0-9\.]+$/) {
        throw EBox::Exceptions::InvalidData(
                'data' => __('account name'),
                'value' => $name,
                'advice' =>  __('Windows group names cannot be only spaces, numbers and dots'),
           );
    }
}

# Method: isSecurityGroup
#
#   Whether is a security group or just a distribution group.
#
sub isSecurityGroup
{
    my ($self) = @_;

    return $self->get('groupType') & GROUPTYPESECURITY;
}

# Method: setSecurityGroup
#
#   Sets/unsets this group as a security group.
#
sub setSecurityGroup
{
    my ($self, $isSecurityGroup, $lazy) = @_;

    my $groupType = $self->get('groupType');

    if ($isSecurityGroup) {
        $groupType |= GROUPTYPESECURITY;
    } else {
        $groupType &= ~GROUPTYPESECURITY;
    }

    $self->set('groupType', $groupType, $lazy);
}

1;
