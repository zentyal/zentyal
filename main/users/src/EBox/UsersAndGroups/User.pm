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
use EBox::UsersAndGroups;

use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;

use constant MAXUSERLENGTH  => 128;
use constant MAXPWDLENGTH   => 512;
use constant SYSMINUID      => 1900;
use constant MINUID         => 2000;
use constant HOMEPATH       => '/home';

# Method: new
#
#   Instance a user LDAP readed from LDAP.
#
#   Parameters:
#
#      dn - Full dn for the user
#  or
#      entry - Net::LDAP entry for the user
#
sub new
{
    my ($class, %params) = @_;

    my $self = {};
    bless($self, $class);



    unless ( $params{entry} or $params{dn} ) {
        throw EBox::Exceptions::MissingArgument('dn');
    }

    if ( $params{entry} ) {
        $self->{entry} = $params{entry};
        $self->{dn} = $params{entry}->dn();
    }
    else {
        $self->{dn} = $params{dn};
    }

    return $self;
}



# Method: get
#
#   Read an user attribute
#
#   Parameters:
#
#       attribute - Attribute name to read
#
sub get
{
    my ($self, $attr) = @_;

    return $self->_entry->get_value($attr);
}


# Method: set
#
#   Set an user attribute
#
#   Parameters:
#
#       attribute - Attribute name to read
#       value     - Value to set (scalar or array ref)
#       lazy      - Do not update the entry in LDAP
#
sub set
{
    my ($self, $attr, $value, $lazy) = @_;

    $self->_entry->replace($attr => $value);
    $self->save() unless $lazy;
}


# Method: delete
#
#   Delete an user attribute
#
#   Parameters:
#
#       attribute - Attribute name to read
#       lazy      - Do not update the entry in LDAP
#
sub delete
{
    my ($self, $attr, $lazy) = @_;

    $self->_entry->delete($attr);
    $self->save() unless $lazy;
}


# Method: save
#
#   Store all pending lazy operations (if any)
#
#   This method is only needed if some operation
#   was used using lazy flag
#
sub save
{
    my ($self) = @_;
    $self->_entry->update($self->_ldap->{ldap});
}


# Method: dn
#
#   Return DN for this user
#
sub dn
{
    my ($self) = @_;

    return $self->_entry->dn();
}


# Method: system
#
#   Return 1 if this is a system user, 0 if not
#
sub system
{
    my ($self) = @_;

    return ($self->get('gidNumber') > MINUID);
}


# Method: changePassword
#
#   Configure a new password for the user
#
sub changePassword
{
    my ($self, $passwd) = @_;

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

    $self->save();
}

# Return Net::LDAP::Entry entry for the user
sub _entry
{
    my ($self) = @_;

    unless ($self->{entry})
    {
        my %attrs = (
            base => $self->{dn},
            filter => 'objectclass=*',
            scope => 'base',
        );

        my $result = $self->_ldap->search(\%attrs);
        $self->{entry} = $result->entry(0);
    }

    return $self->{entry};
}


sub _ldap
{
    my ($self) = @_;

    return EBox::Global->modInstance('users')->ldap();
}



# USER CREATION:


# Method: create
#
#       Adds a new user
#
# Parameters:
#
#       user - hash ref containing: 'user'(user name), 'fullname', 'password',
#       'givenname', 'surname' and 'comment'
#       system - boolean: if true it adds the user as system user, otherwise as
#       normal user
#       uidNumber - user UID numberer (optional and named)
#       additionalPasswords - list with additional passwords (optional)
sub create
{
    my ($self, $user, $system, %params) = @_;

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
# TODO
#    if ($self->userExists($user->{'user'})) {
#        throw EBox::Exceptions::DataExists('data' => __('user name'),
#                                           'value' => $user->{'user'});
#    }

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

    my $gid = $self->groupGid(EBox::UsersAndGroups->DEFAULTGROUP);

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

            @additionalPasswords = @{ EBox::UsersAndGroups::Passwords::additionalPasswords($user->{'user'}, $user->{'password'}) };
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

    my @attr =  (
        'cn'            => $user->{'fullname'},
        'uid'           => $user->{'user'},
        'sn'            => $user->{'surname'},
        'loginShell'    => $self->_loginShell(),
        'uidNumber'     => $uid,
        'gidNumber'     => $gid,
        'homeDirectory' => $homedir,
        'userPassword'  => $passwd,
        'quota'         => $self->defaultQuota(),
        'objectclass'   => [
            'inetOrgPerson',
            'posixAccount',
            'passwordHolder',
            'systemQuotas',
        ],
        @additionalPasswords
    );

    my %args = ( attr => \@attr );

    my $dn = "uid=" . $user->{'user'} . "," . $self->usersDn;
    my $r = $self->ldap->add($dn, \%args);


    $self->_changeAttribute($dn, 'givenName', $user->{'givenname'});
    $self->_changeAttribute($dn, 'description', $user->{'comment'});
    unless ($system) {
        $self->initUser($user->{'user'}, $user->{'password'});
    }
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

1;
