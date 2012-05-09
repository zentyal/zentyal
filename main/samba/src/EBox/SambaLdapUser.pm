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

package EBox::SambaLdapUser;

use strict;
use warnings;

use MIME::Base64;
use Encode;
use Error qw(:try);

use EBox::Sudo;
use EBox::Samba;
use EBox::UsersAndGroups::User;
use EBox::UsersAndGroups::Group;

# Home path for users and groups
use constant BASEPATH           => '/home/ebox/samba';
use constant USERSPATH          => '/home';
use constant GROUPSPATH         => BASEPATH . '/groups';
use constant PROFILESPATH       => BASEPATH . '/profiles';

use base qw(EBox::LdapUserBase);

sub new
{
    my $class = shift;
    my $self  = {};
    $self->{samba} = EBox::Global->modInstance('samba');
    $self->{ldb} = $self->{samba}->ldb();
    bless($self, $class);

    return $self;
}

# Method: _addUSer
#
#   This method adds the user to LDB
#
sub _addUser
{
    my ($self, $user, $password) = @_;

    return unless ($self->{samba}->configured());

    my $uid = $user->get('uid');
    my $uidNumber  = $user->get('uidNumber');
    my $gidNumber  = $user->get('gidNumber');

    my $attrs = {};
    $attrs->{objectClass} = 'user';
    $attrs->{sAMAccountName} = $uid;
    $attrs->{userPrincipalName} = "$uid\@" . $self->{samba}->realm();
    $attrs->{givenName} =  $user->get('givenName');
    $attrs->{sn} = $user->get('sn');
    if (length $user->get('description') > 0) {
        $attrs->{description} = $user->get('description');
    }

    EBox::debug("Creating roaming profile directory for samba user '$uid'");
    my $profileDir = PROFILESPATH . "/$uid";
    $self->_createDir($profileDir, $uidNumber, $gidNumber, '0700');

    try {
        # TODO Support multiples OU
        EBox::debug("Adding user '$uid' to LDB");
        my $dn = "CN=$uid,CN=Users," . $self->{ldb}->rootDN();
        $self->{ldb}->disableZentyalModule();
        $self->{ldb}->add($self->{ldb}->SAM(), $dn, $attrs);
        $self->{ldb}->xidMapping($uid, $uidNumber);
    } otherwise {
        my $error = shift;
        EBox::error($error);
    } finally {
        $self->{ldb}->enableZentyalModule();
    };
}

sub _modifyUser
{
    my ($self, $user, $password) = @_;

    my $uid = $user->get('uid');
    my $changes = $user->modifications();

    my $ldbChanges = {};
    if (exists $changes->{delete}->{description}) {
        $ldbChanges->{delete}->{description} = [];
    }
    if (exists $changes->{replace}->{description}) {
        $ldbChanges->{replace}->{description} = $changes->{replace}->{description};
    }
    if (exists $changes->{replace}->{givenname}) {
        $ldbChanges->{replace}->{givenName} = $changes->{replace}->{givenname};
    }
    if (exists $changes->{replace}->{sn}) {
        $ldbChanges->{replace}->{sn} = $changes->{replace}->{sn};
    }
    if (exists $changes->{replace}->{userPassword}) {
        my $pwd = "\"$password\"";
        $pwd = encode('UTF16-LE', $pwd);
        $pwd = encode_base64($pwd);
        $ldbChanges->{replaceB64}->{unicodePwd} = [ $pwd ];
        $ldbChanges->{replace}->{userAccountControl} = [ '512' ];
    }

    try {
        my $args = { base   => $self->{ldb}->rootDN(),
                     scope  => 'sub',
                     filter => "(sAMAccountName=$uid)",
                     attrs  => 'distinguishedName' };
        my $result = $self->{ldb}->search($self->{ldb}->SAM(), $args);

        return unless (scalar @{$result} == 1);

        my $entry = pop $result;
        my $dn = $entry->get_value('distinguishedName');

        $self->{ldb}->disableZentyalModule();
        $self->{ldb}->modify($self->{ldb}->SAM(), $dn, $ldbChanges);
    } otherwise {
        my $error = shift;
        EBox::error($error);
    } finally {
        $self->{ldb}->enableZentyalModule();
    };
}

sub _delUser
{
    my ($self, $user) = @_;

    return unless ($self->{samba}->configured());

    my $uid = $user->get('uid');

    my @cmds;
    if (-d PROFILESPATH . "/$uid") {
        push (@cmds, "rm -rf \'" .  PROFILESPATH . "/$uid\'");
    }
    EBox::Sudo::root(@cmds) if (@cmds);

    try {
        my $args = { base   => $self->{ldb}->rootDN(),
                     scope  => 'sub',
                     filter => "(sAMAccountName=$uid)",
                     attrs  => 'distinguishedName' };
        my $result = $self->{ldb}->search($self->{ldb}->SAM(), $args);

        return unless (scalar @{$result} == 1);

        my $entry = pop $result;
        my $dn = $entry->get_value('distinguishedName');

        EBox::debug("Deleting user '$uid' from LDB");
        $self->{ldb}->disableZentyalModule();
        $self->{ldb}->delete($self->{ldb}->SAM(), $dn);
        # TODO Update shares ACLs
        # TODO Delete xid mapping
    } otherwise {
        my $error = shift;
        EBox::error($error);
    } finally {
        $self->{ldb}->enableZentyalModule();
    };
}

sub _addGroup
{
    my ($self, $group) = @_;

    return unless ($self->{samba}->configured());

    my $gid = $group->get('cn');
    my $gidNumber = $group->get('gidNumber');

    my $attrs = {};
    $attrs->{objectClass} = 'group';
    $attrs->{sAMAccountName} = $gid;
    if (length $group->get('description') > 0) {
        $attrs->{description} = $group->get('description');
    }

    try {
        # TODO Support multiples OU
        EBox::debug("Adding group '$gid' to LDB");
        my $dn = "CN=$gid,CN=Users," . $self->{ldb}->rootDN();
        $self->{ldb}->disableZentyalModule();
        $self->{ldb}->add($self->{ldb}->SAM(), $dn, $attrs);
        $self->{ldb}->xidMapping($gid, $gidNumber);
    } otherwise {
        my $error = shift;
        EBox::error($error);
    } finally {
        $self->{ldb}->enableZentyalModule();
    };

}

sub _modifyGroup
{
    my ($self, $group) = @_;

    return unless ($self->{samba}->configured());

    my $gid = $group->get('cn');
    my $changes = $group->modifications();

    my $ldbChanges = {};
    if (exists $changes->{delete}->{description}) {
        $ldbChanges->{delete}->{description} = [];
    }
    if (exists $changes->{replace}->{description}) {
        $ldbChanges->{replace}->{description} = $changes->{replace}->{description};
    }
    if (exists $changes->{replace}->{member}) {
        my $members = $changes->{replace}->{member};
        # Translate DN's to LDB ones
        foreach my $memberDN (@{$members}) {
            my $user = new EBox::UsersAndGroups::User(dn => $memberDN);
            my $uid  = $user->get('uid');

            my $args = { base   => $self->{ldb}->rootDN(),
                         scope  => 'sub',
                         filter => "(sAMAccountName=$uid)",
                         attrs  => 'distinguishedName' };
            my $result = $self->{ldb}->search($self->{ldb}->SAM(), $args);

            next unless (scalar @{$result} == 1);

            my $entry = pop $result;
            my $dn = $entry->get_value('distinguishedName');

            $memberDN = $dn;
        }

        $ldbChanges->{replace}->{member} = $changes->{replace}->{member};
    }

    try {
        my $args = { base   => $self->{ldb}->rootDN(),
                     scope  => 'sub',
                     filter => "(sAMAccountName=$gid)",
                     attrs  => 'distinguishedName' };
        my $result = $self->{ldb}->search($self->{ldb}->SAM(), $args);

        return unless (scalar @{$result} == 1);

        my $entry = pop $result;
        my $dn = $entry->get_value('distinguishedName');

        $self->{ldb}->disableZentyalModule();
        $self->{ldb}->modify($self->{ldb}->SAM(), $dn, $ldbChanges);
    } otherwise {
        my $error = shift;
        EBox::error($error);
    } finally {
        $self->{ldb}->enableZentyalModule();
    };
}

sub _delGroup
{
    my ($self, $group) = @_;

    return unless ($self->{samba}->configured());

    my $gid = $group->get('cn');

    try {
        my $args = { base   => $self->{ldb}->rootDN(),
                     scope  => 'sub',
                     filter => "(sAMAccountName=$gid)",
                     attrs  => 'distinguishedName' };
        my $result = $self->{ldb}->search($self->{ldb}->SAM(), $args);

        return unless (scalar @{$result} == 1);

        my $entry = pop $result;
        my $dn = $entry->get_value('distinguishedName');

        EBox::debug("Deleting group '$gid' from LDB");
        $self->{ldb}->disableZentyalModule();
        $self->{ldb}->delete($self->{ldb}->SAM(), $dn);
        # TODO Update shares ACLs
        # TODO Delete xid mapping
    } otherwise {
        my $error = shift;
        EBox::error($error);
    } finally {
        $self->{ldb}->enableZentyalModule();
    };
}

sub _createDir
{
    my ($self, $path, $uid, $gid, $chmod) = @_;

    my @cmds;
    push (@cmds, "mkdir -p \'$path\'");
    push (@cmds, "chown $uid:$gid \'$path\'");

    if ($chmod) {
        push (@cmds, "chmod $chmod \'$path\'");
    }

    EBox::debug("Executing @cmds");
    EBox::Sudo::root(@cmds);
}

sub _directoryEmpty
{
    my ($self, $path) = @_;

    opendir(DIR, $path) or return 1;
    my @ent = readdir(DIR);

    return ($#ent == 1);
}

1;
