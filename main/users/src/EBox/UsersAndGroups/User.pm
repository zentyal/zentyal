#!/usr/bin/perl -w

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

# Class: EBox::UsersAndGroups::User
#
#   Zentyal user, stored in LDAP
#

package EBox::UsersAndGroups::User;

use strict;
use warnings;

use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use EBox::UsersAndGroups;
use EBox::UsersAndGroups::Passwords;
use EBox::UsersAndGroups::Group;

use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;

use Perl6::Junction qw(any);

use constant MAXUSERLENGTH  => 128;
use constant MAXPWDLENGTH   => 512;
use constant SYSMINUID      => 1900;
use constant MINUID         => 2000;
use constant HOMEPATH       => '/home';
use constant QUOTA_PROGRAM  => EBox::Config::scripts('users') . 'user-quota';
use constant CORE_ATTRS     => ( 'cn', 'uid', 'sn', 'givenName',
                                 'loginShell', 'uidNumber', 'gidNumber',
                                 'homeDirectory', 'quota', 'userPassword' );

use base 'EBox::UsersAndGroups::LdapObject';

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    return $self;
}

# Method: name
#
#   Return user name
#
sub name
{
    my ($self) = @_;
    return $self->get('uid');
}


sub fullname
{
    my ($self) = @_;
    return $self->get('cn');
}


sub firstname
{
    my ($self) = @_;
    return $self->get('givenName');
}


sub surname
{
    my ($self) = @_;
    return $self->get('sn');
}


sub home
{
    my ($self) = @_;
    return $self->get('homeDirectory');
}


sub quota
{
    my ($self) = @_;
    return $self->get('quota');
}


sub comment
{
    my ($self) = @_;
    return $self->get('description');
}



# Catch some of the set ops which need special actions
sub set
{
    my ($self, $attr, $value) = @_;

    # remember changes in core attributes (notify LDAP user base modules)
    if ($attr eq any CORE_ATTRS) {
        $self->{core_changed} = 1;
    }
    if ($attr eq 'quota') {
        if ($self->_checkQuota($value)) {
            throw EBox::Exceptions::InvalidData('data' => __('user quota'),
                    'value' => $value,
                    'advice' => __('User quota must be an integer. To set an unlimited quota, enter zero.'),
                    );
        }

        # set quota on save
        $self->{set_quota} = 1;
    }

    shift @_;
    $self->SUPER::set(@_);
}


sub save
{
    my ($self, $ignore_mods) = @_;

    if ($self->{set_quota}) {
        $self->_setFilesystemQuota($self->get('quota'));
        delete $self->{set_quota};
    }

    shift @_;
    $self->SUPER::save(@_);

    if ($self->{core_changed}) {

        my $passwd = $self->{core_changed_password};
        delete $self->{core_changed};
        delete $self->{core_changed_password};

        my $users = EBox::Global->modInstance('users');
        $users->notifyModsLdapUserBase('modifyUser', [ $self, $passwd ], $ignore_mods);
    }
}


# Method: addGroup
#
#   Add this user to the given group
#
# Parameters:
#
#   group - Group object
#
sub addGroup
{
    my ($self, $group) = @_;

    $group->addMember($self);
}


# Method: removeGroup
#
#   Removes this user from the given group
#
# Parameters:
#
#   group - Group object
#
sub removeGroup
{
    my ($self, $group) = @_;

    $group->removeMember($self);
}


# Method: groups
#
#   Groups this user belongs to
#
#   Parameters:
#
#       system - return also system groups (default: false) *optional*
#
#   Returns:
#
#       array ref of EBox::UsersAndGroups::Group objects
#
sub groups
{
    my ($self, $system) = @_;

    return $self->_groups($system);
}


# Method: groupsNotIn
#
#   Groups this user does not belong to
#
#   Parameters:
#
#       system - return also system groups (default: false) *optional*
#
#   Returns:
#
#       array ref of EBox::UsersAndGroups::Group objects
#
sub groupsNotIn
{
    my ($self, $system) = @_;

    return $self->_groups($system, 1);
}

sub _groups
{
    my ($self, $system, $invert) = @_;

    my $filter;
    if ($invert) {
        $filter = "(&(objectclass=zentyalGroup)(!(member=$self->{dn})))";
    } else {
        $filter = "(&(objectclass=zentyalGroup)(member=$self->{dn}))";
    }

    my %attrs = (
        base => $self->_ldap->dn(),
        filter => $filter,
        scope => 'sub',
    );

    my $result = $self->_ldap->search(\%attrs);

    my @groups;
    if ($result->count > 0)
    {
        foreach my $entry ($result->sorted('cn'))
        {
            if (not $system) {
                next if ($entry->get_value('gidNumber') < EBox::UsersAndGroups::Group->MINGID);
            }
            push (@groups, new EBox::UsersAndGroups::Group(entry => $entry));
        }
    }
    return \@groups;
}


# Method: system
#
#   Return 1 if this is a system user, 0 if not
#
sub system
{
    my ($self) = @_;

    return ($self->get('uidNumber') < MINUID);
}


sub _checkQuota
{
    my ($quota) = @_;

    ($quota =~ /^\s*$/) and return undef;
    ($quota =~ /\D/) and return undef;
    return 1;
}


sub _setFilesystemQuota
{
    my ($self, $userQuota) = @_;

    my $uid = $self->get('uidNumber');
    my $quota = $userQuota * 1024;
    EBox::Sudo::root(QUOTA_PROGRAM . " -s $uid $quota");
}

# Method: changePassword
#
#   Configure a new password for the user
#
sub changePassword
{
    my ($self, $passwd, $lazy) = @_;

    $self->_checkPwdLength($passwd);
    my $hash = EBox::UsersAndGroups::Passwords::defaultPasswordHash($passwd);

    #remove old passwords
    my $delattrs = [];
    foreach my $attr ($self->_entry->attributes) {
        if ($attr =~ m/^ebox(.*)Password$/) {
            $self->delete($attr, 1);
        }
    }

    $self->set('userPassword', $hash, 1);

    my $hashes = EBox::UsersAndGroups::Passwords::additionalPasswords($self->get('uid'), $passwd);
    foreach my $attr (keys %$hashes)
    {
        $self->set($attr, $hashes->{$attr}, 1);
    }

    # save password for later LDAP user base mods on save()
    $self->{core_changed_password} = $passwd;
    $self->save() unless ($lazy);
}


# Method: deleteObject
#
#   Delete the user
#
sub deleteObject
{
    my ($self, $ignore_mods) = @_;

    # remove this user from all its grups
    foreach my $group (@{$self->groups()}) {
        $self->removeGroup($group);
    }

    # Notify users deletion to modules
    my $users = EBox::Global->modInstance('users');
    $users->notifyModsLdapUserBase('delUser', $self, $ignore_mods);

    # Call super implementation
    shift @_;
    $self->SUPER::deleteObject(@_);
}


# USER CREATION:


# Method: create
#
#       Adds a new user
#
# Parameters:
#
#   user - hash ref containing: 'user'(user name), 'fullname', 'password',
#   'givenname', 'surname' and 'comment'
#   system - boolean: if true it adds the user as system user, otherwise as
#   normal user
#   params hash (all optional):
#      uidNumber - user UID numberer
#      additionalPasswords - list with additional passwords
#      ignore_mods - ldap modules to be ignored on addUser notify
#      ou (multiple_ous enabled only)
#
# Returns:
#
#   Returns the new create user object
#
sub create
{
    my ($self, $user, $system, %params) = @_;

    my $users = EBox::Global->modInstance('users');

    # Is the user added to the default OU?
    my $isDefaultOU = 1;
    my $dn;
    if (EBox::Config::configkey('multiple_ous') and $params{ou}) {
        $dn = 'uid=' . $user->{user} . ',' . $params{ou};
        $isDefaultOU = ($dn eq $users->usersDn());
    }
    else {
        $dn = $users->userDn($user->{'user'});
    }

    if (length($user->{'user'}) > MAXUSERLENGTH) {
        throw EBox::Exceptions::External(
            __x("Username must not be longer than {maxuserlength} characters",
                maxuserlength => MAXUSERLENGTH));
    }

    my @userPwAttrs = getpwnam($user->{'user'});
    if (@userPwAttrs) {
        throw EBox::Exceptions::External(
            __("Username already exists on the system")
        );
    }
    unless (_checkName($user->{'user'})) {
        throw EBox::Exceptions::InvalidData('data' => __('user name'),
                                            'value' => $user->{'user'});
    }

    # Verify user exists
    if (new EBox::UsersAndGroups::User(dn => $dn)->exists()) {
        throw EBox::Exceptions::DataExists('data' => __('user name'),
                                           'value' => $user->{'user'});
    }

    my $homedir = _homeDirectory($user->{'user'});
    if (-e $homedir) {
        throw EBox::Exceptions::External(
            __x('Cannot create user because the home directory {dir} already exists. Please move or remove it before creating this user',
                dir => $homedir)
        );
    }

    my $uid = exists $params{uidNumber} ?
                     $params{uidNumber} :
                     $self->_newUserUidNumber($system);
    $self->_checkUid($uid, $system);


    my $defaultGroupDN = $users->groupDn(EBox::UsersAndGroups->DEFAULTGROUP);
    my $group = new EBox::UsersAndGroups::Group(dn => $defaultGroupDN);
    my $gid = $group->get('gidNumber');

    my $passwd = $user->{'password'};

    # system user could not have passwords
    if (not $passwd and not $system) {
        throw EBox::Exceptions::MissingArgument(__('Password'));
    }
    my @additionalPasswords = ();
    if ($passwd) {
        $self->_checkPwdLength($user->{'password'});

        if (not isHashed($passwd)) {
            $passwd = EBox::UsersAndGroups::Passwords::defaultPasswordHash($passwd);
        }

        if (exists $params{additionalPasswords}) {
            @additionalPasswords = @{ $params{additionalPasswords} }
        } else {
            # build addtional passwords using not-hashed pasword
            if (isHashed($user->{password})) {
                throw EBox::Exceptions::Internal('The supplied user password is already hashed, you must supply an additional password list');
            }

            my %passwords = %{EBox::UsersAndGroups::Passwords::additionalPasswords($user->{'user'}, $user->{'password'})};
            @additionalPasswords = map { $_ => $passwords{$_} } keys %passwords;
        }
    }

    # If fullname is not specified we build it with
    # givenname and surname
    unless (defined $user->{'fullname'}) {
        $user->{'fullname'} = '';
        if ($user->{'givenname'}) {
            $user->{'fullname'} = $user->{'givenname'} . ' ';
        }
        $user->{'fullname'} .= $user->{'surname'};
    }

    my $quota = $self->defaultQuota();
    my @attr =  (
        'cn'            => $user->{'fullname'},
        'uid'           => $user->{'user'},
        'sn'            => $user->{'surname'},
        'givenName'     => $user->{givenname},
        'loginShell'    => $self->_loginShell(),
        'uidNumber'     => $uid,
        'gidNumber'     => $gid,
        'homeDirectory' => $homedir,
        'userPassword'  => $passwd,
        'quota'         => $quota,
        'objectclass'   => [
            'inetOrgPerson',
            'posixAccount',
            'passwordHolder',
            'systemQuotas',
        ],
        @additionalPasswords
    );

    push (@attr, 'description' => $user->{comment}) if ($user->{comment});

    my %args = ( attr => \@attr );

    my $r = $self->_ldap->add($dn, \%args);
    my $res = new EBox::UsersAndGroups::User(dn => $dn);

    # Init user
    unless ($system) {
        # only default OU users are initializated
        if ($isDefaultOU) {
            $users->reloadNSCD();
            $users->initUser($res, $user->{'password'});
            $res->_setFilesystemQuota($quota);
        }

        # Call modules initialization
        $users->notifyModsLdapUserBase('addUser', [ $res, $user->{'password'} ], $params{ignore_mods});
    }

    # Return the new created user
    return $res;
}

sub isHashed
{
    my ($pwd) = @_;
    return ($pwd =~ /^\{[0-9A-Z]+\}/);
}

sub _checkName
{
    my ($name) = @_;

    if ($name =~ /^([a-zA-Z\d\s_-]+\.)*[a-zA-Z\d\s_-]+$/) {
        return 1;
    } else {
        return undef;
    }
}

sub _homeDirectory
{
    my ($username) = @_;

    my $home = HOMEPATH . '/' . $username;
    return $home;
}

# Method: lastUid
#
#       Returns the last uid used.
#
# Parameters:
#
#       system - boolean: if true, it returns the last uid for system users,
#                         otherwise the last uid for normal users
#
# Returns:
#
#       string - last uid
#
sub lastUid
{
    my ($self, $system) = @_;

    my $lastUid = -1;
    while (my ($name, undef, $uid) = getpwent()) {
        next if ($name eq 'nobody');

        if ($system) {
            last if ($uid >= MINUID);
        } else {
            next if ($uid < MINUID);
        }
        if ($uid > $lastUid) {
            $lastUid = $uid;
        }
    }
    endpwent();

    if ($system) {
        return ($lastUid < SYSMINUID ? SYSMINUID : $lastUid);
    } else {
        return ($lastUid < MINUID ? MINUID : $lastUid);
    }
}



sub _newUserUidNumber
{
    my ($self, $systemUser) = @_;

    my $uid;
    if ($systemUser) {
        $uid = $self->lastUid(1) + 1;
        if ($uid == MINUID) {
            throw EBox::Exceptions::Internal(
                __('Maximum number of system users reached'));
        }
    } else {
        $uid = $self->lastUid + 1;
    }

    return $uid;
}

sub _checkUid
{
    my ($self, $uid, $system) = @_;

    if ($uid < MINUID) {
        if (not $system) {
            throw EBox::Exceptions::External(
                __x('Incorrect UID {uid} for a user . UID must be equal or greater than {min}',
                    uid => $uid,
                    min => MINUID,
                   )
                );
        }
    }
    else {
        if ($system) {
            throw EBox::Exceptions::External(
                __x('Incorrect UID {uid} for a system user . UID must be lesser than {max}',
                    uid => $uid,
                    max => MINUID,
                   )
                );
        }
    }
}


sub _checkPwdLength
{
    my ($self, $pwd) = @_;

    # Is hashed?
    if ($pwd =~ /^\{[0-9A-Z]+\}/) {
        return;
    }

    if (length($pwd) > MAXPWDLENGTH) {
        throw EBox::Exceptions::External(
            __x("Password must not be longer than {maxPwdLength} characters",
            maxPwdLength => MAXPWDLENGTH));
    }
}

sub _loginShell
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');
    return $users->model('PAM')->login_shellValue();
}

sub defaultQuota
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');
    my $model = $users->model('AccountSettings');

    my $value = $model->defaultQuotaValue();
    if ($value eq 'defaultQuota_disabled') {
        $value = 0;
    }

    return $value;
}



1;
