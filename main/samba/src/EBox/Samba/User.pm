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

# Class: EBox::Samba::User
#
#   Samba user, stored in samba LDAP
#
package EBox::Samba::User;

use base 'EBox::Samba::SecurityPrincipal';

use EBox::Global;
use EBox::Gettext;

use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::UnwillingToPerform;
use EBox::Exceptions::Internal;

use EBox::Samba::Credentials;

use EBox::Users::User;
use EBox::Samba::Group;

use Perl6::Junction qw(any);
use Encode qw(encode);
use Net::LDAP::Control;
use Net::LDAP::Entry;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);
use Date::Calc;
use Error qw(:try);

use constant MAXUSERLENGTH  => 128;
use constant MAXPWDLENGTH   => 512;

# UserAccountControl flags extracted from http://support.microsoft.com/kb/305144
use constant SCRIPT                         => 0x00000001;
use constant ACCOUNTDISABLE                 => 0x00000002;
use constant HOMEDIR_REQUIRED               => 0x00000008;
use constant LOCKOUT                        => 0x00000010;
use constant PASSWD_NOTREQD                 => 0x00000020;
use constant PASSWD_CANT_CHANGE             => 0x00000040;
use constant ENCRYPTED_TEXT_PWD_ALLOWED     => 0x00000080;
use constant TEMP_DUPLICATE_ACCOUNT         => 0x00000100;
use constant NORMAL_ACCOUNT                 => 0x00000200;
use constant INTERDOMAIN_TRUST_ACCOUNT      => 0x00000800;
use constant WORKSTATION_TRUST_ACCOUNT      => 0x00001000;
use constant SERVER_TRUST_ACCOUNT           => 0x00002000;
use constant DONT_EXPIRE_PASSWORD           => 0x00010000;
use constant MNS_LOGON_ACCOUNT              => 0x00020000;
use constant SMARTCARD_REQUIRED             => 0x00040000;
use constant TRUSTED_FOR_DELEGATION         => 0x00080000;
use constant NOT_DELEGATED                  => 0x00100000;
use constant USE_DES_KEY_ONLY               => 0x00200000;
use constant DONT_REQ_PREAUTH               => 0x00400000;
use constant PASSWORD_EXPIRED               => 0x00800000;
use constant TRUSTED_TO_AUTH_FOR_DELEGATION => 0x01000000;
use constant PARTIAL_SECRETS_ACCOUNT        => 0x04000000;

# Method: mainObjectClass
#
sub mainObjectClass
{
    return 'user';
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
    $self->set('unicodePwd', $passwd, 1);
    try {
        $self->save() unless $lazy;
    } otherwise {
        my ($error) = @_;

        throw EBox::Exceptions::External($error->error());
    };
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
    my ($self, @params) = @_;

    if (not $self->checkObjectErasability()) {
        throw EBox::Exceptions::UnwillingToPerform(
            reason => __x('The object {x} is a system critical object.',
                          x => $self->dn()));
    }

    # Remove the roaming profile directory
    my $samAccountName = $self->get('samAccountName');
    my $path = EBox::Samba::PROFILES_DIR() . "/$samAccountName";
    EBox::Sudo::silentRoot("rm -rf '$path'");

    # TODO Remove this user from shares ACLs

    # Call super implementation
    $self->SUPER::deleteObject(@params);
}

sub setupUidMapping
{
    my ($self, $uidNumber) = @_;

    my $type = $self->_ldap->idmap->TYPE_UID();
    $self->_ldap->idmap->setupNameMapping($self->sid(), $type, $uidNumber);
}

# Method: setAccountEnabled
#
#   Enables or disables the user account.
#
sub setAccountEnabled
{
    my ($self, $enable, $lazy) = @_;

    unless (defined $enable) {
        throw EBox::Exceptions::MissingArgument('enable');
    }
    my $flags = $self->get('userAccountControl');
    if ($enable) {
        $flags = $flags & ~ACCOUNTDISABLE;
    } else {
        $flags = $flags | ACCOUNTDISABLE;
    }
    $self->set('userAccountControl', $flags, 1);

    $self->save() unless $lazy;
}

# Method: isAccountEnabled
#
#   Check if the account is enabled, reading the userAccountControl
#   attribute. For a description of this attribute check:
#   http://support.microsoft.com/kb/305144
#
# Returns:
#
#   boolean - 1 if enabled, 0 if disabled
#
sub isAccountEnabled
{
    my ($self) = @_;

    return not ($self->get('userAccountControl') & ACCOUNTDISABLE);
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

sub createRoamingProfileDirectory
{
    my ($self) = @_;

    my $domainSid       = $self->_ldap->domainSID();
    my $samAccountName  = $self->get('samAccountName');
    my $userSID         = $self->sid();
    my $domainAdminsSID = "$domainSid-512";
    my $domainUsersSID  = "$domainSid-513";

    # Create the directory if it does not exist
    my $path  = EBox::Samba::PROFILES_DIR() . "/$samAccountName";
    my $group = EBox::Users::DEFAULTGROUP();

    my @cmds = ();
    # Create the directory if it does not exist
    push (@cmds, "mkdir -p \'$path\'") unless -d $path;

    # Set unix permissions on directory
    push (@cmds, "chown $samAccountName:$group \'$path\'");
    push (@cmds, "chmod 0700 \'$path\'");

    # Set native NT permissions on directory
    my @perms;
    push (@perms, 'u:root:rwx');
    push (@perms, 'g::---');
    push (@perms, "g:$group:---");
    push (@perms, "u:$samAccountName:rwx");
    push (@cmds, "setfacl -b \'$path\'");
    push (@cmds, 'setfacl -R -m ' . join(',', @perms) . " \'$path\'");
    push (@cmds, 'setfacl -R -m d:' . join(',d:', @perms) ." \'$path\'");
    EBox::Sudo::root(@cmds);
}

sub setRoamingProfile
{
    my ($self, $enable, $path, $lazy) = @_;

    if ($enable) {
        my $userName = $self->get('samAccountName');
        $self->createRoamingProfileDirectory();
        $path .= "\\$userName";
        $self->set('profilePath', $path, $lazy);
    } else {
        $self->delete('profilePath', $lazy);
    }
    $self->save() unless $lazy;
}

sub setHomeDrive
{
    my ($self, $drive, $path, $lazy) = @_;

    my $userName = $self->get('samAccountName');
    $path .= "\\$userName";
    $self->set('homeDrive', $drive);
    $self->set('homeDirectory', $path);
    $self->save() unless $lazy;
}

# Method: create
#
# FIXME: We should find a way to share code with the Contact::create method using the common class. I had to revert it
# because an OrganizationalPerson reconversion to a User failed.
#
#   Adds a new user
#
# Parameters:
#
#   args - Named parameters:
#       name
#       givenName
#       initials
#       sn
#       displayName
#       description
#       mail
#       samAccountName - string with the user name
#       clearPassword - Clear text password
#       kerberosKeys - Set of kerberos keys
#       uidNumber - user UID number
#
# Returns:
#
#   Returns the new create user object
#
sub create
{
    my ($class, %args) = @_;

    # Check for required arguments.
    throw EBox::Exceptions::MissingArgument('samAccountName') unless ($args{samAccountName});
    throw EBox::Exceptions::MissingArgument('name') unless ($args{name});
    throw EBox::Exceptions::MissingArgument('parent') unless ($args{parent});
    throw EBox::Exceptions::InvalidData(
        data => 'parent', value => $args{parent}->dn()) unless ($args{parent}->isContainer());

    my $samAccountName = $args{samAccountName};
    $class->_checkAccountName($samAccountName, MAXUSERLENGTH);

    # Check the password length if specified
    my $clearPassword = $args{'clearPassword'};
    if (defined $clearPassword) {
        $class->_checkPwdLength($clearPassword);
    }

    my $name = $args{name};
    my $dn = "CN=$name," .  $args{parent}->dn();

    # Check DN is unique (duplicated givenName and surname)
    $class->_checkDnIsUnique($dn, $name);

    $class->_checkAccountNotExists($name);
    my $usersMod = EBox::Global->modInstance('users');
    my $realm = $usersMod->kerberosRealm();

    my @attr = ();
    push (@attr, objectClass => ['top', 'person', 'organizationalPerson', 'user']);
    push (@attr, cn          => $name);
    push (@attr, name        => $name);
    push (@attr, givenName   => $args{givenName}) if ($args{givenName});
    push (@attr, initials    => $args{initials}) if ($args{initials});
    push (@attr, sn          => $args{sn}) if ($args{sn});
    push (@attr, displayName => $args{displayName}) if ($args{displayName});
    push (@attr, description => $args{description}) if ($args{description});
    push (@attr, sAMAccountName => $samAccountName);
    push (@attr, userPrincipalName => "$samAccountName\@$realm");
    # All accounts are, by default Normal and disabled accounts.
    push (@attr, userAccountControl => NORMAL_ACCOUNT | ACCOUNTDISABLE);

    my $res = undef;
    my $entry = undef;
    try {
        $entry = new Net::LDAP::Entry($dn, @attr);
        my $result = $entry->update($class->_ldap->connection());
        if ($result->is_error()) {
            unless ($result->code() == LDAP_LOCAL_ERROR and $result->error() eq 'No attributes to update') {
                throw EBox::Exceptions::LDAP(
                    message => __('Error on person LDAP entry creation:'),
                    result => $result,
                    opArgs => $class->entryOpChangesInUpdate($entry),
                );
            };
        }

        $res = new EBox::Samba::User(dn => $dn);

        # Set the password
        if (defined $args{clearPassword}) {
            $res->changePassword($args{clearPassword});
            $res->setAccountEnabled(1);
        } elsif (defined $args{kerberosKeys}) {
            $res->setCredentials($args{kerberosKeys});
            $res->setAccountEnabled(1);
        }

        if (defined $args{uidNumber}) {
            $res->setupUidMapping($args{uidNumber});
        }
    } otherwise {
        my ($error) = @_;

        EBox::error($error);

        if (defined $res and $res->exists()) {
            $res->SUPER::deleteObject(@_);
        }
        $res = undef;
        $entry = undef;
        throw $error;
    };

    return $res;
}

sub _checkAccountName
{
    my ($self, $name, $maxLength) = @_;
    $self->SUPER::_checkAccountName($name, $maxLength);
    if ($name =~ m/^[[:space:]\.]+$/) {
        throw EBox::Exceptions::InvalidData(
                'data' => __('account name'),
                'value' => $name,
                'advice' =>   __('Windows user names cannot be only spaces and dots.')
           );
    } elsif ($name =~ m/@/) {
        throw EBox::Exceptions::InvalidData(
                'data' => __('account name'),
                'value' => $name,
                'advice' =>   __('Windows user names cannot contain the "@" character.')
           );
    }
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

sub _checkDnIsUnique
{
    my ($self, $dn, $name) = @_;

    my $entry = new EBox::Samba::LdbObject(dn => $dn);
    if ($entry->exists()) {
        throw EBox::Exceptions::DataExists(
            text => __x('User name {x} already exists in the same container.',
                        x => $name));
    }
}

sub addToZentyal
{
    my ($self) = @_;

    my $sambaMod = EBox::Global->modInstance('samba');
    my $parent = $sambaMod->ldapObjectFromLDBObject($self->parent);

    if (not $parent) {
        my $dn = $self->dn();
        throw EBox::Exceptions::External("Unable to to find the container for '$dn' in OpenLDAP");
    }
    my $uid = $self->get('samAccountName');
    my $givenName = $self->givenName();
    my $surname = $self->surname();
    $givenName = '-' unless $givenName;
    $surname = '-' unless $surname;

    my $zentyalUser = undef;
    EBox::info("Adding samba user '$uid' to Zentyal");
    try {
        my %args = (
            uid          => scalar ($uid),
            parent       => $parent,
            fullname     => scalar($self->name()),
            givenname    => scalar($givenName),
            initials     => scalar($self->initials()),
            surname      => scalar($surname),
            displayname  => scalar($self->displayName()),
            description  => scalar($self->description()),
            ignoreMods   => ['samba'],
        );

        my $uidNumber = $self->xidNumber();
        unless (defined $uidNumber) {
            throw EBox::Exceptions::Internal("Could not get uidNumber for user $uid");
        }
        $args{uidNumber} = $uidNumber;
        $args{isSystemUser} = ($uidNumber < EBox::Users::User->MINUID());

        if ($self->isInAdvancedViewOnly() or $sambaMod->hiddenSid($self)) {
            $args{isInternal} = 1;
        }

        $zentyalUser = EBox::Users::User->create(%args);
    } catch EBox::Exceptions::DataExists with {
        EBox::debug("User $uid already in OpenLDAP database");
        $zentyalUser = new EBox::Users::User(uid => $uid);
    } otherwise {
        my $error = shift;
        EBox::error("Error loading user '$uid': $error");
    };

    if ($zentyalUser) {
        $zentyalUser->setIgnoredModules(['samba']);

        if ($self->isAccountEnabled()) {
            $zentyalUser->setDisabled(0);
        } else {
            $zentyalUser->setDisabled(1);
        }

        my $sc = $self->get('supplementalCredentials');
        my $up = $self->get('unicodePwd');
        if ($sc or $up) {
            # There are some accounts that lack credentials, like Guest account.
            my $creds = new EBox::Samba::Credentials(
                supplementalCredentials => $sc,
                unicodePwd => $up
            );
            $zentyalUser->setKerberosKeys($creds->kerberosKeys());
        } else {
            EBox::warn("The user $uid doesn't have credentials!");
        }

        $self->_linkWithUsersObject($zentyalUser);

        # Only set global roaming profiles and drive letter options
        # if we are not replicating to another Windows Server to avoid
        # overwritting already existing per-user settings. Also skip if
        # unmanaged_home_directory config key is defined
        unless ($sambaMod->mode() eq 'adc') {
            EBox::info("Setting roaming profile for $uid...");
            my $netbiosName = $sambaMod->netbiosName();
            my $realmName = EBox::Global->modInstance('users')->kerberosRealm();
            # Set roaming profiles
            if ($sambaMod->roamingProfiles()) {
                my $path = "\\\\$netbiosName.$realmName\\profiles";
                $self->setRoamingProfile(1, $path, 1);
            } else {
                $self->setRoamingProfile(0, undef, 1);
            }

            # Mount user home on network drive
            my $drivePath = "\\\\$netbiosName.$realmName";
            my $unmanagedHomes = EBox::Config::boolean('unmanaged_home_directory');
            $self->setHomeDrive($sambaMod->drive(), $drivePath, 1) unless $unmanagedHomes;
            $self->save();
        }
    }
}

sub updateZentyal
{
    my ($self) = @_;

    my $uid = $self->get('samAccountName');
    EBox::info("Updating zentyal user '$uid'");

    my $zentyalUser = undef;
    my $givenName = $self->givenName();
    my $surname = $self->surname();
    my $fullName = $self->name();
    my $initials = $self->initials();
    my $displayName = $self->displayName();
    my $description = $self->description();
    $givenName = '-' unless $givenName;
    $surname = '-' unless $surname;

    $zentyalUser = $self->_sambaMod()->ldapObjectFromLDBObject($self);
    unless ($zentyalUser) {
        throw EBox::Exceptions::Internal("Zentyal user '$uid' does not exist");
    }

    $zentyalUser->setIgnoredModules(['samba']);
    $zentyalUser->set('cn', $fullName, 1);
    $zentyalUser->set('givenName', $givenName, 1);
    $zentyalUser->set('initials', $initials, 1);
    $zentyalUser->set('sn', $surname, 1);
    $zentyalUser->set('displayName', $displayName, 1);
    $zentyalUser->set('description', $description, 1);
    if ($self->isAccountEnabled()) {
        $zentyalUser->setDisabled(0, 1);
    } else {
        $zentyalUser->setDisabled(1, 1);
    }
    $zentyalUser->save();

    my $sc = $self->get('supplementalCredentials');
    my $up = $self->get('unicodePwd');
    if ($sc or $up) {
        # There are some accounts that lack credentials, like Guest account.
        my $creds = new EBox::Samba::Credentials(
            supplementalCredentials => $sc,
            unicodePwd => $up
        );
        $zentyalUser->setKerberosKeys($creds->kerberosKeys());
    } else {
        EBox::warn("The user $uid doesn't have credentials!");
    }
}

1;
