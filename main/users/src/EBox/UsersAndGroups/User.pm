#!/usr/bin/perl -w

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

# Class: EBox::UsersAndGroups::User
#
#   Zentyal user, stored in LDAP
#

package EBox::UsersAndGroups::User;
use base 'EBox::UsersAndGroups::LdapObject';

use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use EBox::UsersAndGroups;
use EBox::UsersAndGroups::Group;

use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::LDAP;

use Perl6::Junction qw(any);
use Error qw(:try);
use Convert::ASN1;
use Net::LDAP::Entry;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);

use constant MAXUSERLENGTH  => 128;
use constant MAXPWDLENGTH   => 512;
use constant SYSMINUID      => 1900;
use constant MINUID         => 2000;
use constant MAXUID         => 2**31;
use constant HOMEPATH       => '/home';
use constant QUOTA_PROGRAM  => EBox::Config::scripts('users') . 'user-quota';
use constant QUOTA_LIMIT    => 2097151;
use constant CORE_ATTRS     => ( 'cn', 'uid', 'sn', 'givenName',
                                 'loginShell', 'uidNumber', 'gidNumber',
                                 'homeDirectory', 'quota', 'userPassword',
                                 'description', 'krb5Key');

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = {};

    if (defined $opts{uid}) {
        $self->{uid} = $opts{uid};
    } else {
        $self = $class->SUPER::new(@_);
    }

    bless ($self, $class);
    return $self;
}

# Method: _entry
#
#   Return Net::LDAP::Entry entry for the user
#
sub _entry
{
    my ($self) = @_;

    unless ($self->{entry}) {
        if (defined $self->{uid}) {
            my $result = undef;
            my $attrs = {
                base => $self->_ldap->dn(),
                filter => "(uid=$self->{uid})",
                scope => 'sub',
            };
            $result = $self->_ldap->search($attrs);
            if ($result->count() > 1) {
                throw EBox::Exceptions::Internal(
                    __x('Found {count} results for, expected only one.',
                        count => $result->count()));
            }
            $self->{entry} = $result->entry(0);
        } else {
            $self->SUPER::_entry();
        }
    }
    return $self->{entry};
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

sub internal
{
    my ($self) = @_;

    my $title = $self->get('title');
    return (defined ($title) and ($title eq 'internal'));
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

# Catch some of the delete ops which need special actions
sub delete
{
    my ($self, $attr, $value) = @_;

    # remember changes in core attributes (notify LDAP user base modules)
    if ($attr eq any CORE_ATTRS) {
        $self->{core_changed} = 1;
    }

    shift @_;
    $self->SUPER::delete(@_);
}

sub save
{
    my ($self) = @_;

    my $changetype = $self->_entry->changetype();

    if ($self->{set_quota}) {
        my $quota = $self->get('quota');
        $self->_checkQuota($quota);
        $self->_setFilesystemQuota($quota);
        delete $self->{set_quota};
    }

    my $passwd = delete $self->{core_changed_password};
    if (defined $passwd) {
        $self->_ldap->changeUserPassword($self->dn(), $passwd);
    }

    shift @_;
    $self->SUPER::save(@_);

    if ($changetype ne 'delete') {
        if ($self->{core_changed} or defined $passwd) {
            delete $self->{core_changed};

            my $users = EBox::Global->modInstance('users');
            $users->notifyModsLdapUserBase('modifyUser', [ $self, $passwd ], $self->{ignoreMods}, $self->{ignoreSlaves});
        }
    }
}

# Method: setIgnoredModules
#
#   Set the modules that should not be notified of the changes
#   made to this object
#
# Parameters:
#
#   mods - Array reference cotaining module names
#
sub setIgnoredModules
{
    my ($self, $mods) = @_;
    $self->{ignoreMods} = $mods;
}

# Method: setIgnoredSlaves
#
#   Set the slaves that should not be notified of the changes
#   made to this object
#
# Parameters:
#
#   mods - Array reference cotaining slave names
#
sub setIgnoredSlaves
{
    my ($self, $slaves) = @_;
    $self->{ignoreSlaves} = $slaves;
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
    my $dn = $self->dn();
    if ($invert) {
        $filter = "(&(objectclass=zentyalGroup)(!(member=$dn)))";
    } else {
        $filter = "(&(objectclass=zentyalGroup)(member=$dn))";
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
        foreach my $entry ($result->entries())
        {
            if (not $system) {
                next if ($entry->get_value('gidNumber') < EBox::UsersAndGroups::Group->MINGID);
            }
            push (@groups, new EBox::UsersAndGroups::Group(entry => $entry));
        }
        # sort grups by name
        @groups = sort {
            my $aValue = $a->name();
            my $bValue = $b->name();
            (lc $aValue cmp lc $bValue) or
                ($aValue cmp $bValue)
        } @groups;
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
    my ($self, $quota) = @_;

    my $integer = $quota =~ m/^\d+$/;
    if (not $integer) {
        throw EBox::Exceptions::InvalidData('data' => __('user quota'),
                                            'value' => $quota,
                                            'advice' => __(
'User quota must be a positive integer. To set an unlimited quota, enter zero.'
                                                          ),
                                           );
    }

    if ($quota > QUOTA_LIMIT) {
        throw EBox::Exceptions::InvalidData(
            data => __('user quota'),
            value => $quota,
            advice => __x('The maximum value is {max} MB',
                          max => QUOTA_LIMIT),
        );
    }
}

sub _setFilesystemQuota
{
    my ($self, $userQuota) = @_;

    my $uid = $self->get('uidNumber');
    my $quota = $userQuota * 1024;
    EBox::Sudo::root(QUOTA_PROGRAM . " -s $uid $quota");

    # check if quota has been really set
    my $output = EBox::Sudo::root(QUOTA_PROGRAM . " -q $uid");
    my ($afterQuota) = $output->[0] =~ m/(\d+)/;
    if ((not defined $afterQuota) or ($quota != $afterQuota)) {
        EBox::error(
            __x('Cannot set quota for uid {uid} to {userQuota}. Maybe your file system does not support quota?',
                uid      => $uid,
                userQuota => $userQuota)
           );
    }
}

# Method: changePassword
#
#   Configure a new password for the user
#
sub changePassword
{
    my ($self, $passwd, $lazy) = @_;

    $self->_checkPwdLength($passwd);

    # The password will be changed on save, save it also to
    # notify LDAP user base mods
    $self->{core_changed_password} = $passwd;
    $self->save() unless $lazy;
}

# Method: setPasswordFromHashes
#
#   Configure user password directly from its kerberos hashes
#
# Parameters:
#
#   passwords - array ref of krb5keys
#
sub setPasswordFromHashes
{
    my ($self, $passwords, $lazy) = @_;

    $self->set('userPassword', '{K5KEY}', $lazy);
    $self->set('krb5Key', $passwords, $lazy);
    $self->set('krb5KeyVersionNumber', 1, $lazy);
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

    # Notify users deletion to modules
    my $users = EBox::Global->modInstance('users');
    $users->notifyModsLdapUserBase('delUser', $self, $self->{ignoreMods}, $self->{ignoreSlaves});

    # Mark as changed to process save
    $self->{core_changed} = 1;

    # Call super implementation
    shift @_;
    $self->SUPER::deleteObject(@_);
}

# Method: passwordHashes
#
#   Return an array ref to all krb hashed passwords as:
#
#   [ hash, hash, ... ]
#
sub passwordHashes
{
    my ($self) = @_;

    my @keys = $self->get('krb5Key');
    return \@keys;
}

# USER CREATION:

# Method: create
#
#       Adds a new user
#
# Parameters:
#
#   user - hash ref containing:
#       user - user name
#       password
#       fullname (optional)
#       givenname
#       surname
#       comment
#       ou (optional) # TODO param conflict, wrong doc
#   system - boolean: if true it adds the user as system user, otherwise as
#                     normal user
#   params hash (all optional):
#      uidNumber - user UID number
#      ou (multiple_ous enabled only)
#      ignoreMods - modules that should not be notified about the user creation
#      ignoreSlaves - slaves that should not be notified about the user creation
#
# Returns:
#
#   Returns the new create user object
#
sub create
{
    my ($self, $user, $system, %params) = @_;

    my $users = EBox::Global->modInstance('users');

    unless (_checkUserName($user->{'user'})) {
        my $advice = __('To avoid problems, the username should consist only ' .
                        'of letters, digits, underscores, spaces, periods, ' .
                        'dashs, not start with a dash and not end with dot');

        throw EBox::Exceptions::InvalidData('data' => __('user name'),
                                            'value' => $user->{'user'},
                                            'advice' => $advice
                                           );
    }

    my $real_users = $users->realUsers('without_admin');

    my $max_users = 0;
    if (EBox::Global->modExists('remoteservices')) {
        my $rs = EBox::Global->modInstance('remoteservices');
        if ($users->master() eq 'cloud') {
            $max_users = $rs->maxCloudUsers();
        } else {
            $max_users = $rs->maxUsers();
        }
    }

    if ($max_users) {
        if ( scalar(@{$real_users}) > $max_users ) {
            throw EBox::Exceptions::External(
                    __sx('Please note that the maximum number of users for your edition is {max} '
                        . 'and you currently have {nUsers}',
                        max => $max_users, nUsers => scalar(@{$real_users})));
        }
    }

    # Is the user added to the default OU?
    my $isDefaultOU = 1;
    my $dn;
    if (EBox::Config::configkey('multiple_ous') and $user->{ou}) {
        $dn = 'uid=' . $user->{user} . ',' . $user->{ou};
        $isDefaultOU = ($user->{ou} eq $users->usersDn());
    }
    else {
        $dn = $users->userDn($user->{'user'});
    }

    if (length($user->{'user'}) > MAXUSERLENGTH) {
        throw EBox::Exceptions::External(
            __x("Username must not be longer than {maxuserlength} characters",
                maxuserlength => MAXUSERLENGTH));
    }

    # Verify user exists
    if (new EBox::UsersAndGroups::User(dn => $dn)->exists()) {
        throw EBox::Exceptions::DataExists('data' => __('user name'),
                                           'value' => $user->{'user'});
    }
    # Verify than a group with the same name does not exists
    if ($users->groupExists($user->{user})) {
        throw EBox::Exceptions::External(
            __x(q{A group account with the name '{name}' already exists. Users and groups cannot share names},
               name => $user->{user})
           );
    }

    my @userPwAttrs = getpwnam($user->{'user'});
    if (@userPwAttrs) {
        throw EBox::Exceptions::External(
            __("Username already exists on the system")
        );
    }

    my $homedir = _homeDirectory($user->{'user'});
    if (-e $homedir) {
        throw EBox::Exceptions::External(
            __x('Cannot create user because the home directory {dir} already exists. Please move or remove it before creating this user',
                dir => $homedir)
        );
    }

    # Check the password length if specified
    my $passwd = $user->{'password'};
    if (defined $passwd) {
        $self->_checkPwdLength($passwd);
    }

    my $uid = exists $params{uidNumber} ?
                     $params{uidNumber} :
                     $self->_newUserUidNumber($system);
    $self->_checkUid($uid, $system);

    my $defaultGroupDN = $users->groupDn(EBox::UsersAndGroups->DEFAULTGROUP);
    my $group = new EBox::UsersAndGroups::Group(dn => $defaultGroupDN);
    my $gid = $group->get('gidNumber');

    # If fullname is not specified we build it with
    # givenname and surname
    unless (defined $user->{'fullname'}) {
        $user->{'fullname'} = '';
        if ($user->{'givenname'}) {
            $user->{'fullname'} = $user->{'givenname'} . ' ';
        }
        $user->{'fullname'} .= $user->{'surname'};
    }

    my $realm = $users->kerberosRealm();
    my $quota = $self->defaultQuota();
    my @attr = (
        'cn'            => $user->{fullname},
        'uid'           => $user->{user},
        'sn'            => $user->{surname},
        'givenName'     => $user->{givenname},
        'loginShell'    => $self->_loginShell(),
        'uidNumber'     => $uid,
        'gidNumber'     => $gid,
        'homeDirectory' => $homedir,
        'quota'         => $quota,
        'objectclass'   => [
            'inetOrgPerson',
            'posixAccount',
            'passwordHolder',
            'systemQuotas',
            'krb5Principal',
            'krb5KDCEntry'
        ],
        'krb5PrincipalName'    => $user->{user} . '@' . $realm,
        'krb5KeyVersionNumber' => 0,
        'krb5MaxLife'          => 86400,  # TODO
        'krb5MaxRenew'         => 604800, # TODO
        'krb5KDCFlags'         => 126,    # TODO
    );

    push (@attr, 'description' => $user->{comment}) if ($user->{comment});

    if ($params{internal}) {
        push (@attr, 'title' => 'internal') if ($params{internal});
    }

    my $res = undef;
    my $entry = undef;
    try {
        # Call modules initialization. The notified modules can modify the entry,
        # add or delete attributes.
        $entry = new Net::LDAP::Entry($dn, @attr);
        unless ($system) {
            $users->notifyModsPreLdapUserBase('preAddUser', $entry,
                $params{ignoreMods}, $params{ignoreSlaves});
        }

        my $result = $entry->update($self->_ldap->{ldap});
        if ($result->is_error()) {
            unless ($result->code == LDAP_LOCAL_ERROR and $result->error eq 'No attributes to update') {
                throw EBox::Exceptions::LDAP(
                    message => __('Error on user LDAP entry creation:'),
                    result => $result,
                    opArgs => $self->entryOpChangesInUpdate($entry),
                   );
            };
    }

        $res = new EBox::UsersAndGroups::User(dn => $dn);

        # Set the user password and kerberos keys
        if (defined $passwd) {
            $self->_checkPwdLength($passwd);
            $res->_ldap->changeUserPassword($res->dn(), $passwd);
            # Force reload of krb5Keys
            $res->clearCache();
        }
        elsif (defined($user->{passwords})) {
            $res->setPasswordFromHashes($user->{passwords});
        }

        # Init user
        unless ($system) {
            # only default OU users are initializated
            if ($isDefaultOU) {
                $users->reloadNSCD();
                $users->initUser($res, $passwd);
                $res->_setFilesystemQuota($quota);
            }

            # Call modules initialization
            $users->notifyModsLdapUserBase('addUser', [ $res, $passwd ], $params{ignoreMods}, $params{ignoreSlaves});
        }
    } otherwise {
        my ($error) = @_;

        EBox::error($error);

        # A notified module has thrown an exception. Delete the object from LDAP
        # Call to parent implementation to avoid notifying modules about deletion
        # TODO Ideally we should notify the modules for beginTransaction,
        #      commitTransaction and rollbackTransaction. This will allow modules to
        #      make some cleanup if the transaction is aborted
        if (defined $res and $res->exists()) {
            $users->notifyModsLdapUserBase('addUserFailed', [ $res ], $params{ignoreMods}, $params{ignoreSlaves});
            $res->SUPER::deleteObject(@_);
        } else {
            $users->notifyModsPreLdapUserBase('preAddUserFailed', [ $entry ], $params{ignoreMods}, $params{ignoreSlaves});
        }
        $res = undef;
        $entry = undef;
        EBox::Sudo::root("rm -rf $homedir") if (-e $homedir);
        throw $error;
    };

    if ($res->{core_changed}) {
        # save() will be take also of saving password if it is changed
        $res->save();
    }

    # Return the new created user
    return $res;
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

sub _checkUserName
 {
     my ($name) = @_;
    if (not EBox::UsersAndGroups::checkNameLimitations($name)) {
        return undef;
    }


    # windows user names cannot end with a  period
    if ($name =~ m/\.$/) {
        return undef;
    }

    return 1;
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
    my $users = EBox::Global->modInstance('users');
    foreach my $user (@{$users->users($system)}) {
        my $uid = $user->get('uidNumber');
        if ($system) {
            last if ($uid >= MINUID);
        } else {
            next if ($uid < MINUID);
        }
        if ($uid > $lastUid) {
            $lastUid = $uid;
        }
    }

    if ($system) {
        return ($lastUid < SYSMINUID ? SYSMINUID : $lastUid);
    } else {
        return ($lastUid < MINUID ? MINUID : $lastUid);
    }
}

sub _newUserUidNumber
{
    my ($self, $systemUser) = @_;

    my $uid = $self->lastUid($systemUser);
    do {
        # try next uid in order
        $uid++;

        if ($systemUser) {
            if ($uid >= MINUID) {
                throw EBox::Exceptions::Internal(
                    __('Maximum number of system users reached'));
            }
        } else {
            if ($uid >= MAXUID) {
                throw EBox::Exceptions::Internal(
                        __('Maximum number of users reached'));
            }
        }

        # check if uid is already used
    } while (defined getpwuid($uid));

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

# Method: kerberosKeys
#
#     Return the Kerberos key hashes for this user
#
# Returns:
#
#     Array ref - containing three hash refs with the following keys
#
#         type  - Int the hash type (18 => DES-CBC-CRC, 16 => DES-CBC-MD5,
#                                    23 => arcfour-HMAC-MD5 (AKA NTLMv2)
#         value - Octects containing the hash
#
#         salt  - String the salt (only valid for 18 and 16 types)
#
sub kerberosKeys
{
    my ($self) = @_;

    my $keys = [];

    my $syntaxFile = EBox::Config::scripts('users') . 'krb5Key.asn';
    my $asn = Convert::ASN1->new();
    $asn->prepare_file($syntaxFile) or
        throw EBox::Exceptions::Internal($asn->error());
    my $asn_key = $asn->find('Key') or
        throw EBox::Exceptions::Internal($asn->error());

    my @aux = $self->get('krb5Key');
    foreach my $blob (@aux) {
        my $key = $asn_key->decode($blob) or
            throw EBox::Exceptions::Internal($asn_key->error());
        push @{$keys}, {
                         type  => $key->{key}->{value}->{keytype}->{value},
                         value => $key->{key}->{value}->{keyvalue}->{value},
                         salt  => $key->{salt}->{value}->{salt}->{value}
                       };
    }

    return $keys;
}

sub setKerberosKeys
{
    my ($self, $keys) = @_;

    unless (defined $keys) {
        throw EBox::Exceptions::MissingArgument('keys');
    }

    my $syntaxFile = EBox::Config::scripts('users') . 'krb5Key.asn';
    my $asn = Convert::ASN1->new();
    $asn->prepare_file($syntaxFile) or
        throw EBox::Exceptions::Internal($asn->error());
    my $asn_key = $asn->find('Key') or
        throw EBox::Exceptions::Internal($asn->error());

    my $blobs = [];
    foreach my $key (@{$keys}) {
        my $salt = undef;
        if (defined $key->{salt}) {
            $salt = {
                value => {
                    type => {
                        value => 3
                    },
                    salt => {
                        value => $key->{salt}
                    },
                    opaque => {
                        value => '',
                    },
                },
            };
        }

        my $blob = $asn_key->encode(
            mkvno => {
                value => 0
            },
            salt => $salt,
            key => {
                value => {
                    keytype => {
                        value =>  $key->{type}
                    },
                    keyvalue => {
                        value => $key->{value}
                    }
                }
            }) or
        throw EBox::Exceptions::Internal($asn_key->error());
        push (@{$blobs}, $blob);
    }
    $self->set('krb5Key', $blobs);
    $self->set('userPassword', '{K5KEY}');
}

1;
