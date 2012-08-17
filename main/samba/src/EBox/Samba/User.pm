#!/usr/bin/perl

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

# Class: EBox::Samba::User
#
#   Samba user, stored in samba LDAP
#

package EBox::Samba::User;

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;

use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;

use Perl6::Junction qw(any);
use Encode;
use Net::LDAP::Control;

use constant MAXUSERLENGTH  => 128;
use constant MAXPWDLENGTH   => 512;

use base 'EBox::Samba::LdbObject';

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless ($self, $class);
    return $self;
}

# Catch some of the set ops which need special actions
#sub set
#{
#    my ($self, $attr, $value) = @_;
#
#    # remember changes in core attributes (notify LDAP user base modules)
#    if ($attr eq any CORE_ATTRS) {
#        $self->{core_changed} = 1;
#    }
#    if ($attr eq 'quota') {
#        if ($self->_checkQuota($value)) {
#            throw EBox::Exceptions::InvalidData('data' => __('user quota'),
#                    'value' => $value,
#                    'advice' => __('User quota must be an integer. To set an unlimited quota, enter zero.'),
#                    );
#        }
#
#        # set quota on save
#        $self->{set_quota} = 1;
#    }
#
#    shift @_;
#    $self->SUPER::set(@_);
#}

# Catch some of the delete ops which need special actions
#sub delete
#{
#    my ($self, $attr, $value) = @_;
#
#    # remember changes in core attributes (notify LDAP user base modules)
#    if ($attr eq any CORE_ATTRS) {
#        $self->{core_changed} = 1;
#    }
#
#    shift @_;
#    $self->SUPER::delete(@_);
#}

#sub save
#{
#    my ($self) = @_;
#
#    my $changetype = $self->_entry->changetype();
#
#    if ($self->{set_quota}) {
#        my $quota = $self->get('quota');
#        $self->_checkQuota($quota);
#        $self->_setFilesystemQuota($quota);
#        delete $self->{set_quota};
#    }
#
#    my $passwd = delete $self->{core_changed_password};
#    if (defined $passwd) {
#        $self->_ldap->changeUserPassword($self->dn(), $passwd);
#    }
#
#    shift @_;
#    $self->SUPER::save(@_);
#
#    if ($changetype ne 'delete') {
#        if ($self->{core_changed} or defined $passwd) {
#            delete $self->{core_changed};
#
#            my $users = EBox::Global->modInstance('users');
#            $users->notifyModsLdapUserBase('modifyUser', [ $self, $passwd ], $self->{ignoreMods}, $self->{ignoreSlaves});
#
#            delete $self->{ignoreMods};
#        }
#    }
#}

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
# Returns:
#
#   array ref of EBox::Samba::Group objects
#
sub groups
{
    my ($self) = @_;

    return $self->_groups();
}

# Method: groupsNotIn
#
#   Groups this user does not belong to
#
# Returns:
#
#   array ref of EBox::UsersAndGroups::Group objects
#
sub groupsNotIn
{
    my ($self) = @_;

    return $self->_groups(1);
}

sub _groups
{
    my ($self, $invert) = @_;

    my $dn = $self->dn();
    my $filter;
    if ($invert) {
        $filter = "(&(objectclass=group)(!(member=$dn)))";
    } else {
        $filter = "(&(objectclass=group)(member=$dn))";
    }

    my $attrs = {
        base => $self->_ldap->dn(),
        filter => $filter,
        scope => 'sub',
    };

    my $result = $self->_ldap->search($attrs);

    my $groups = [];
    if ($result->count > 0) {
        foreach my $entry ($result->sorted('cn')) {
            push (@{$groups}, new EBox::Samba::Group(entry => $entry));
        }
    }
    return $groups;
}

# Method: changePassword
#
#   Configure a new password for the user
#
sub changePassword
{
    my ($self, $passwd, $lazy) = @_;

    $self->_checkPwdLength($passwd);

    $passwd = encode('UTF16-LE', "\"$passwd\"");

    # The password will be changed on save
    $self->delete('unicodePwd', 1);
    $self->add('unicodePwd', $passwd, 1);
    $self->save() unless $lazy;
}

# Method: setCredentials
#
#   Configure user credentials directly from kerberos hashes
#
# Parameters:
#
#   keys - array ref of krb5keys
#
sub setCredentials
{
    my ($self, $keys, $lazy) = @_;

    my $pwdSet = 0;
    my $credentials = new EBox::Samba::Credentials(krb5Keys => $keys);
    if ($credentials->supplementalCredentials()) {
        $self->set('supplementalCredentials', $credentials->supplementalCredentials(), 1);
        $pwdSet = 1;
    }
    if ($credentials->unicodePwd()) {
        $self->set('unicodePwd', $credentials->unicodePwd(), 1);
        $pwdSet = 1;
    }

    if ($pwdSet) {
        # This value is stored as a large integer that represents
        # the number of 100 nanosecond intervals since January 1, 1601 (UTC)
        my ($sec, $min, $hour, $day, $mon, $year) = gmtime(time);
        $year = $year + 1900;
        $mon += 1;
        my $days = Date::Calc::Delta_Days(1601, 1, 1, $year, $mon, $day);
        my $secs = $sec + $min * 60 + $hour * 3600 + $days * 86400;
        my $val = $secs * 10000000;
        $self->set('pwdLastSet', $val, 1);
    }

    my $bypassControl = Net::LDAP::Control->new(
        type => '1.3.6.1.4.1.7165.4.3.12',
        critical => 1 );
    $self->save($bypassControl) unless $lazy;
}

# Method: deleteObject
#
#   Delete the user
#
sub deleteObject
{
    my ($self) = @_;

    # remove this user from all its grups
    foreach my $group (@{$self->groups()}) {
        $self->removeGroup($group);
    }

    # Call super implementation
    shift @_;
    $self->SUPER::deleteObject(@_);
}

sub setupUidMapping
{
    my ($self, $uidNumber) = @_;

    # NOTE Samba4 beta2 support rfc2307, reading uidNumber from ldap instead idmap.ldb, but
    # it is not working when the user init session as DOMAIN/user but user@domain.com
    # FIXME Remove this when fixed
    my $type = $self->_ldap->idmap->TYPE_UID();
    $self->_ldap->idmap->setupNameMapping($self->sid(), $type, $uidNumber);
}

sub setAccountEnabled
{
    my ($self, $enabled, $lazy) = @_;

    if ($enabled) {
        $self->set('userAccountControl', 512, 1);
    } else {
        $self->set('userAccountControl', 514, 1);
    }

    $self->save() unless $lazy;
}

# Method: addSpn
#
#   Add a service principal name to this account
#
sub addSpn
{
    my ($self, $spn, $lazy) = @_;

    my @spns = $self->get('servicePrincipalName');

    # return if spn already present
    foreach my $s (@spns) {
        return if (lc ($s) eq lc ($spn));
    }
    push (@spns, $spn);

    $self->set('servicePrincipalName', \@spns, $lazy);
}

# Method: create
#
#   Adds a new user
#
# Parameters:
#
#   user - hash ref containing:
#       'samAccountName'
#
#   params hash ref (all optional):
#      clearPassword - Clear text password
#      uidNumber - user UID numberer
#      ou - OU where the user will be created
#
# Returns:
#
#   Returns the new create user object
#
sub create
{
    my ($self, $samAccountName, $params) = @_;

    # TODO Is the user added to the default OU?
    my $baseDn = $self->_ldap->dn();
    my $dn = "CN=$samAccountName,CN=Users,$baseDn";

    $self->_checkAccountName($samAccountName, MAXUSERLENGTH);

    # Verify user exists
    if (new EBox::Samba::User(dn => $dn)->exists()) {
        throw EBox::Exceptions::DataExists('data' => __('user name'),
                                           'value' => $samAccountName);
    }

    # Check the password length if specified
    my $clearPassword = $params->{'clearPassword'};
    if (defined $clearPassword) {
        $self->_checkPwdLength($clearPassword);
    }

    my $usersModule = EBox::Global->modInstance('users');
    my $realm = $usersModule->kerberosRealm();
    my $attr = [];
    push ($attr, objectClass       => [ 'top', 'person', 'organizationalPerson', 'user', 'posixAccount' ]);
    push ($attr, sAMAccountName    => "$samAccountName");
    push ($attr, userPrincipalName => "$samAccountName\@$realm");
    push ($attr, userAccountControl => '514');
    # FIXME push ($attr, sn                => $sn);
    # FIXME push ($attr, givenName         => $givenName);
    push ($attr, uidNumber         => $params->{uidNumber}) if defined $params->{uidNumber};
    push ($attr, description       => $params->{description}) if defined $params->{description};

    # Add the entry
    my $result = $self->_ldap->add($dn, { attr => $attr });
    my $createdUser = new EBox::Samba::User(dn => $dn);

    # Setup the uid mapping
    $createdUser->setupUidMapping($params->{uidNumber}) if defined $params->{uidNumber};

    # Set the password
    if (exists $params->{clearPassword}) {
        $createdUser->changePassword($params->{clearPassword});
        $createdUser->setAccountEnabled(1);
    } elsif (exists $params->{kerberosKeys}) {
        $createdUser->setCredentials($params->{kerberosKeys});
        $createdUser->setAccountEnabled(1);
    }

    # Return the new created user
    return $createdUser;
}

sub _checkPwdLength
{
    my ($self, $pwd) = @_;

    if (length($pwd) > MAXPWDLENGTH) {
        throw EBox::Exceptions::External(
                __x("Password must not be longer than {maxPwdLength} characters",
                    maxPwdLength => MAXPWDLENGTH));
    }
}

1;
