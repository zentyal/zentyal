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

# Class: EBox::Users::User
#
#   Zentyal user, stored in LDAP
#

package EBox::Users::User;

use base 'EBox::Users::InetOrgPerson';

use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use EBox::Users;
use EBox::Users::Group;

use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::LDAP;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::Internal;

use Perl6::Junction qw(any);
use TryCatch::Lite;
use Convert::ASN1;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);

use constant MAXUSERLENGTH  => 128;
use constant MAXPWDLENGTH   => 512;
use constant SYSMINUID      => 1900;
use constant MINUID         => 2000;
use constant MAXUID         => 2**31;
use constant HOMEPATH       => '/home';
use constant QUOTA_PROGRAM  => EBox::Config::scripts('users') . 'user-quota';
use constant QUOTA_LIMIT    => 2097151;

sub new
{
    my $class = shift;
    my %opts = @_;

    my $coreAttrs = ['uid', 'loginShell', 'uidNumber', 'gidNumber', 'homeDirectory', 'quota', 'userPassword', 'krb5Key'];
    $opts{idField} = 'uid';
    $opts{coreAttrs} = $coreAttrs;
    my $self = $class->SUPER::new(%opts);

    if (defined $opts{uid}) {
        $self->{uid} = $opts{uid};
    }

    bless ($self, $class);
    return $self;
}

# Method: mainObjectClass
#
#  Returns:
#     object class name which will be used to discriminate users
sub mainObjectClass
{
    return 'posixAccount';
}

sub printableType
{
    return __('user');
}

# Clss method: defaultContainer
#
#   Parameters:
#     ro - wether to use the read-only version of the users module
#
#   Return the default container that will hold Group objects.
#
sub defaultContainer
{
    my ($package, $ro) = @_;
    my $usersMod = EBox::Global->getInstance($ro)->modInstance('users');
    return $usersMod->objectFromDN('ou=Users,'.$usersMod->ldap->dn());
}

# Method: uidTag
#
#   Return the tag to store the uid
#
sub uidTag
{
    return 'uid';
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

sub isInternal
{
    my ($self) = @_;

    my $title = $self->get('title');
    return (defined ($title) and ($title eq 'internal'));
}

sub setInternal
{
    my ($self, $internal) = @_;

    if ($internal) {
        $self->set('title', 'internal');
    } else {
        $self->set('title', undef);
    }
}

# Catch some of the set ops which need special actions
sub set
{
    my ($self, $attr, $value) = @_;

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

    my $hasCoreChanges = $self->{core_changed};

    shift @_;
    $self->SUPER::save(@_);

    if ($changetype ne 'delete') {
        if ($hasCoreChanges or defined $passwd) {

            my $usersMod = $self->_usersMod();
            $usersMod->notifyModsLdapUserBase('modifyUser', [ $self, $passwd ], $self->{ignoreMods}, $self->{ignoreSlaves});
        }
    }
}

sub _groups
{
    my ($self, %params) = @_;

    my @groups = @{$self->SUPER::_groups(%params)};

    my $defaultGroup = EBox::Users->DEFAULTGROUP();
    my $filteredGroups = [];
    for my $group (@groups) {
        next if ($group->name() eq $defaultGroup and not $params{internal});
        next if ($group->isInternal() and not $params{internal});
        next if ($group->isSystem() and not $params{system});

        push (@{$filteredGroups}, $group);
    }
    return $filteredGroups;
}

# Method: isSystem
#
#   Return 1 if this is a system user, 0 if not
#
sub isSystem
{
    my ($self) = @_;

    return ($self->get('uidNumber') < MINUID);
}

# Method: isDisabled
#
#   Return true if the user is disabled, false otherwise
#
sub isDisabled
{
    my ($self) = @_;

    # shadowExpire == 0 means disabled, any other value means enabled even not defined.
    my $value = $self->get('shadowExpire');
    if ((defined $value) and ($value eq 0)) {
        return 1;
    } else {
        return 0;
    }
}

# Method: setDisabled
#
#   Enables / disables this user.
#
sub setDisabled
{
    my ($self, $status, $lazy) = @_;

    if ($status) {
        $self->set('shadowExpire', 0, $lazy);
    } else {
        $self->delete('shadowExpire', $lazy);
    }
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

    # Notify users deletion to modules
    my $usersMod = $self->_usersMod();
    $usersMod->notifyModsLdapUserBase('delUser', $self, $self->{ignoreMods}, $self->{ignoreSlaves});

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
#       Adds a new user.
#
# Parameters:
#
#   args - Named parameters:
#       uid    - User name.
#       parent - Parent container that will hold this new User.
#       password
#       fullname
#       givenname
#       initials
#       surname
#       displayname
#       description
#       mail
#       isDisabled   - boolean: Whether this user should be disabled or not. Default False.
#       isSystemUser - boolean: if true it adds the user as system user, otherwise as normal user
#       uidNumber    - user UID number
#       isInternal     - Whether this use is internal or not.
#       ignoreMods   - modules that should not be notified about the user creation
#       ignoreSlaves - slaves that should not be notified about the user creation
#
sub create
{
    my ($class, %args) = @_;

    # Check for required arguments.
    throw EBox::Exceptions::MissingArgument('uid') unless ($args{uid});
    throw EBox::Exceptions::MissingArgument('parent') unless ($args{parent});
    throw EBox::Exceptions::InvalidData(
        data => 'parent', value => $args{parent}->dn()) unless ($args{parent}->isContainer());

    my $uid = $args{uid};
    my $parent = $args{parent};
    my $isSystemUser = 0;
    if ($args{isSystemUser}) {
        $isSystemUser = 1;
    }
    my $isDisabled = 0; # All users are enabled by default.
    if ($args{isDisabled}) {
        $isDisabled = 1;
    }
    my $ignoreMods   = $args{ignoreMods};
    my $ignoreSlaves = $args{ignoreSlaves};

    unless (_checkUserName($uid)) {
        my $advice = __('To avoid problems, the uid should consist only ' .
                        'of letters, digits, underscores, spaces, periods, ' .
                        'dashs, not start with a dash and not end with dot');

        throw EBox::Exceptions::InvalidData('data' => __('user name'),
                                            'value' => $uid,
                                            'advice' => $advice
                                           );
    }

    my $usersMod = EBox::Global->modInstance('users');
    my $real_users = $usersMod->realUsers();

    my $max_users = 0;
    if (EBox::Global->modExists('remoteservices')) {
        my $rs = EBox::Global->modInstance('remoteservices');
        if ($usersMod->master() eq 'cloud') {
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

    if (length($uid) > MAXUSERLENGTH) {
        throw EBox::Exceptions::External(
            __x("Username must not be longer than {maxuserlength} characters",
                maxuserlength => MAXUSERLENGTH));
    }

    # Verify user exists
    my $userExists = $usersMod->userExists($uid);
    if ($userExists and ($userExists == EBox::Users::OBJECT_EXISTS_AND_HIDDEN_SID())) {
        throw EBox::Exceptions::External(__x('The user {uid} already exists as built-in Windows user', uid => $uid));
    } elsif ($userExists) {
        throw EBox::Exceptions::DataExists('data' => __('user name'),
                                           'value' => $uid);
    }
    # Verify that a group with the same name does not exists
    my $groupExists =  $usersMod->groupExists($uid);
    if ($groupExists and ($groupExists == EBox::Users::OBJECT_EXISTS_AND_HIDDEN_SID())) {
        throw EBox::Exceptions::External(
            __x(q{A built-in Windows group with the name '{name}' already exists. Users and groups cannot share names},
               name => $uid)
           );
    } elsif ($groupExists) {
        throw EBox::Exceptions::DataExists(text =>
            __x(q{A group account with the name '{name}' already exists. Users and groups cannot share names},
               name => $uid)
           );
    }

    my $cn = $args{givenname} . ' ' . $args{surname};
    $class->checkCN($parent, $cn);

    my $dn = 'uid=' . $uid . ',' . $parent->dn();

    my @userPwAttrs = getpwnam($uid);
    if (@userPwAttrs) {
        throw EBox::Exceptions::External(__("Username already exists on the system"));
    }

    my $homedir = _homeDirectory($uid);
    if (-e $homedir) {
        EBox::warn("Home directory $homedir already exists when creating user $uid");
    }

    # Check the password length if specified
    my $passwd = $args{'password'};
    if (defined $passwd) {
        $class->_checkPwdLength($passwd);
    }

    my $uidNumber = defined $args{uidNumber} ?
                            $args{uidNumber} :
                            $class->_newUserUidNumber($isSystemUser);
    $class->_checkUid($uidNumber, $isSystemUser);

    my $defaultGroup = $usersMod->groupByName(EBox::Users->DEFAULTGROUP);
    unless ($defaultGroup) {
        throw EBox::Exceptions::Internal(
            __x("The default group '{defaultgroup}' cannot be found!", defaultgroup => EBox::Users->DEFAULTGROUP));
    }
    if (not $defaultGroup->isSecurityGroup()) {
        throw EBox::Exceptions::InvalidData(
            'data' => __('default group'),
            'value' => $defaultGroup->name(),
            'advice' => __('Default group must be a security group.'),
        );
    }
    my $gid = $defaultGroup->get('gidNumber');

    my $realm = $usersMod->kerberosRealm();
    my $quota = $class->defaultQuota();

    my $res = undef;
    my $parentRes = undef;
    my $entry = undef;
    try {
        $args{dn} = $dn;
        $parentRes = $class->SUPER::create(%args);

        my $anyObjectClass = any($parentRes->get('objectClass'));
        my @userExtraObjectClasses = (
            'posixAccount', 'passwordHolder', 'systemQuotas', 'krb5Principal', 'krb5KDCEntry', 'shadowAccount'
        );
        foreach my $extraObjectClass (@userExtraObjectClasses) {
            if ($extraObjectClass ne $anyObjectClass) {
                $parentRes->add('objectClass', $extraObjectClass, 1);
            }
        }
        $parentRes->set('uid', $uid, 1);
        $parentRes->set('loginShell', $class->_loginShell(), 1);
        $parentRes->set('uidNumber', $uidNumber, 1);
        $parentRes->set('gidNumber', $gid, 1);
        $parentRes->set('homeDirectory', $homedir, 1);
        $parentRes->set('quota', $quota, 1);
        if ($isDisabled) {
            $parentRes->set('shadowExpire', 0, 1);
        }
        $parentRes->set('krb5PrincipalName', $uid . '@' . $realm, 1);
        $parentRes->set('krb5KeyVersionNumber', 0, 1);
        $parentRes->set('krb5MaxLife', 86400, 1); # TODO
        $parentRes->set('krb5MaxRenew', 604800, 1); # TODO
        $parentRes->set('krb5KDCFlags', 126, 1); # TODO
        $parentRes->set('title', 'internal', 1) if ($args{isInternal});

        # Call modules initialization. The notified modules can modify the entry, add or delete attributes.
        $entry = $parentRes->_entry();
        unless ($isSystemUser) {
            $usersMod->notifyModsPreLdapUserBase(
                'preAddUser', [$entry, $parent], $ignoreMods, $ignoreSlaves);
        }

        my $result = $entry->update($class->_ldap->{ldap});
        if ($result->is_error()) {
            unless ($result->code == LDAP_LOCAL_ERROR and $result->error eq 'No attributes to update') {
                throw EBox::Exceptions::LDAP(
                    message => __('Error on user LDAP entry creation:'),
                    result => $result,
                    opArgs => $class->entryOpChangesInUpdate($entry),
                   );
            };
        }

        $res = new EBox::Users::User(dn => $dn);

        # Set the user password and kerberos keys
        if (defined $passwd) {
            $class->_checkPwdLength($passwd);
            $res->_ldap->changeUserPassword($res->dn(), $passwd);
            # Force reload of krb5Keys
            $res->clearCache();
        }
        elsif (defined($args{passwords})) {
            $res->setPasswordFromHashes($args{passwords});
        }

        # Init user
        if ($isSystemUser) {
            if ($uidNumber == 0) {
                # Special case to handle Samba's Administrator. It's like a regular user but without quotas.
                $usersMod->reloadNSCD();
                $usersMod->initUser($res, $passwd);

                # Call modules initialization
                $usersMod->notifyModsLdapUserBase(
                    'addUser', [ $res, $passwd ], $ignoreMods, $ignoreSlaves);
            }
        } else {
            $usersMod->reloadNSCD();
            $usersMod->initUser($res, $passwd);
            $res->_setFilesystemQuota($quota);

            # Call modules initialization
            $usersMod->notifyModsLdapUserBase(
                'addUser', [ $res, $passwd ], $ignoreMods, $ignoreSlaves);
        }
    } catch ($error) {
        EBox::error($error);

        # A notified module has thrown an exception. Delete the object from LDAP
        # Call to parent implementation to avoid notifying modules about deletion
        # TODO Ideally we should notify the modules for beginTransaction,
        #      commitTransaction and rollbackTransaction. This will allow modules to
        #      make some cleanup if the transaction is aborted
        if (defined $res and $res->exists()) {
            $usersMod->notifyModsLdapUserBase(
                'addUserFailed', [ $res ], $ignoreMods, $ignoreSlaves);
            $res->SUPER::deleteObject(@_);
        } elsif ($parentRes and $parentRes->exists()) {
            $usersMod->notifyModsPreLdapUserBase(
                'preAddUserFailed', [$entry, $parent], $ignoreMods, $ignoreSlaves);
            $parentRes->deleteObject(@_);
        }
        $res = undef;
        $parentRes = undef;
        $entry = undef;
        EBox::Sudo::root("rm -rf $homedir") if (-e $homedir);
        throw $error;
    }

    if ($res->{core_changed}) {
        # save() will be take also of saving password if it is changed
        $res->save();
    }

    $defaultGroup->setIgnoredModules($ignoreMods);
    $defaultGroup->setIgnoredSlaves($ignoreSlaves);
    $defaultGroup->addMember($res, 1);
    $defaultGroup->save();

    # Return the new created user
    return $res;
}

sub _checkUserName
{
    my ($name) = @_;
    if (not EBox::Users::checkNameLimitations($name)) {
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
    my ($uid) = @_;

    my $home = HOMEPATH . '/' . $uid;
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
    my ($class, $system) = @_;

    my $lastUid = -1;
    my $usersMod = EBox::Global->modInstance('users');
    foreach my $user (@{$usersMod->users($system)}) {
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
    my ($class, $systemUser) = @_;

    my $uid = $class->lastUid($systemUser);
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
    my $usersMod = EBox::Global->modInstance('users');
    return $usersMod->model('PAM')->login_shellValue();
}

sub quotaAvailable
{
    return 1;
}

sub defaultQuota
{
    my $usersMod = EBox::Global->modInstance('users');
    my $model = $usersMod->model('AccountSettings');

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
