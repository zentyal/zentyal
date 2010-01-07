# Copyright (C) 2009 eBox Technologies S.L.
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


package EBox::AsteriskLdapUser;

# Class: EBox::AsteriskLdapUser
#
#

use base qw(EBox::LdapUserBase);

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Ldap;
use EBox::UsersAndGroups;
use EBox::Asterisk::Extensions;
use EBox::Model::ModelManager;

# Group: Public methods

# Constructor: new
#
#      Create the new LDAP helper
#
# Overrides:
#
#      <EBox::LdapUserBase>
#
# Returns:
#
#      <EBox::LdapUserBase> - the recently created model
#
sub new
{
    my $class = shift;

    my $self  = {};
    $self->{ldap} = EBox::Ldap->instance();
    $self->{asterisk} = EBox::Global->modInstance('asterisk');

    bless($self, $class);

    return $self;
}


# Group: Private methods

# Method: _addUser
#
# Implements:
#
#      <EBox::LdapUserBase::_addUser>
#
sub _addUser
{
    my ($self, $user, $passwd, $skipDefault) = @_;

    unless ($self->{asterisk}->configured()) {
        return;
    }

    unless ($skipDefault) {
        my $model = EBox::Model::ModelManager::instance()
            ->model('asterisk/AsteriskUser');
        return unless ($model->enabledValue());
    }

    my $users = EBox::Global->modInstance('users');
    my $ldap = $self->{ldap};

    my $dn = $users->userDn($user);

    my $extensions = new EBox::Asterisk::Extensions;

    my $extn = $extensions->firstFreeExtension();
    my $mail = $self->_getUserMail($user);

    my %attrs = (changes => [
                             add => [
                                     objectClass => 'AsteriskSIPUser',
                                     AstAccountType => 'friend',
                                     AstAccountContext => 'users',
                                     AstAccountCallerID => $extn, #FIXME +fullname?
                                     AstAccountMailbox => $extn,
                                     AstAccountHost => 'dynamic',
                                     AstAccountNAT => 'yes',
                                     AstAccountQualify => 'yes',
                                     AstAccountCanReinvite => 'no',
                                     AstAccountLastms => '0',
                                     AstAccountIPAddress => '0.0.0.0',
                                     AstAccountPort => '0',
                                     AstAccountExpirationTimestamp => '0',
                                     AstAccountRegistrationServer => '0',
                                     AstAccountUserAgent => '0',
                                     AstAccountFullContact => 'sip:0.0.0.0',
                                     objectClass => 'AsteriskVoicemail',
                                     AstAccountVMPassword => $extn, #FIXME random?
                                     AstAccountVMMail => $mail,
                                     AstAccountVMAttach => 'yes',
                                     AstAccountVMDelete => 'no',
                                    ],
                            ]
                );

    my %args = (base => $dn, filter => 'objectClass=AsteriskSIPUser');
    my $result = $ldap->search(\%args);

    unless ($result->count > 0) {
        $ldap->modify($dn, \%attrs);
        if ($extn > 0) { $extensions->addUserExtension($user, $extn); }
    }
}


# FIXME doc
sub _getUserMail
{
    my ($self, $user) = @_;

    my $users = EBox::Global->modInstance('users');

    my %attrs = (
                 base => $users->usersDn,
                 filter => "&(objectclass=*)(uid=$user)",
                 scope => 'one'
                );

    my $result = $self->{'ldap'}->search(\%attrs);

    my $entry = $result->entry(0);
    if ( $entry->get_value('mail') ) {
        return $entry->get_value('mail');
    } else {
        return "user\@domain";
    }
}


# Method: _userAddOns
#
# Implements:
#
#      <EBox::LdapUserBase::_userAddOns>
#
sub _userAddOns
{
    my ($self, $user) = @_;

    my $asterisk = $self->{asterisk};
    return unless ($asterisk->configured());

    my $active = 'no';
    $active = 'yes' if ($self->hasAccount($user));

    my $extensions = new EBox::Asterisk::Extensions;
    my $extn = $extensions->getUserExtension($user);

    my $args = {
        'username' => $user,
        'extension' => $extn,
        'active'   => $active,
        'service' => $asterisk->isEnabled(),
    };

    return { path => '/asterisk/asterisk.mas',
             params => $args };
}


# Method: _delUser
#
# Implements:
#
#      <EBox::LdapUserBase::_delUser>
#
sub _delUser
{
    my ($self, $user) = @_;

    unless ($self->{asterisk}->configured()) {
        return;
    }

    $self->_removeVoicemail($user);

    my $extensions = new EBox::Asterisk::Extensions;
    $extensions->delUserExtension($user);

    my $users = EBox::Global->modInstance('users');
    my $uid = $users->userInfo($user)->{uid};

    my $ldap = $users->{ldap};
    my $dn = "uid=$user," . $users->usersDn;

    $ldap->delObjectclass($dn, 'AsteriskSIPUser');
    $ldap->delObjectclass($dn, 'AsteriskVoicemail');
}


# FIXME doc
sub _removeVoicemail
{
    my ($self, $user) = @_;

    my $extensions = new EBox::Asterisk::Extensions;
    my $voicemail = $extensions->getUserExtension($user);
    if ($voicemail) { # just in case where empty :)
        my $vmpath = $extensions->VOICEMAILDIR . $voicemail;
        EBox::Sudo::root("/bin/rm -fr $vmpath");
    }
}

# Method: setHasAccount
#
#       Enable or disable the Asterisk account for this user. The way it's
#       implementated this method actually create or delete the account.
#
# Parameters:
#
#       username - username object of the action
#       option - 0=disable, 1=enable the account
#
sub setHasAccount
{
    my ($self, $username, $option) = @_;
    defined $option or
        $option = 0;

    my $hasAccount = $self->hasAccount($username);
    ($hasAccount xor $option) or
        return;

    if ($option) {
        $self->_addUser($username, undef, 1);
    } else {
        $self->_delUser($username);
    }
}


# Method: hasAccount
#
#       Check if the user has an Asterisk account
#
# Parameters:
#
#       username - username object of the action
#
# Returns:
#
#       boolean - true if it exists, otherwise false
#
sub hasAccount #($username)
{
    my ($self, $username) = @_;

    my $users = EBox::Global->modInstance('users');
    my $ldap = $self->{ldap};

    my $dn = "uid=$username," . $users->usersDn;

    my %args = (base => $dn, filter => 'objectClass=AsteriskSIPUser');
    my $result = $ldap->search(\%args);

    return 1 if ($result->count != 0);
    return 0;
}

sub schemas
{
    return [ EBox::Config::share() . '/ebox-asterisk/asterisk.ldif' ];
}

sub acls
{
    my ($self) = @_;

    return [
        "to attrs=AstAccountVMPassword,AstAccountVMMail,AstAccountVMAttach," .
        "AstAccountVMDelete " .
        "by dn.regex=\"" . $self->{ldap}->rootDn() . "\" write " .
        "by self write " .
        "by * none" ];
}

# Method: defaultUserModel
#
#   Overrides <EBox::UsersAndGrops::LdapUserBase::defaultUserModel>
#   to return our default user template
sub defaultUserModel
{
    return 'asterisk/AsteriskUser';
}

1;
