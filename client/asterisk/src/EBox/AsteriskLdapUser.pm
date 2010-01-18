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

use Perl6::Junction qw(any);

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
                                     AstAccountDTMFMode => 'rfc2833',
                                     AstAccountInsecure => 'port',
                                     AstAccountLastQualifyMilliseconds => '0',
                                     AstAccountIPAddress => '0.0.0.0',
                                     AstAccountPort => '0',
                                     AstAccountExpirationTimestamp => '0',
                                     AstAccountRegistrationServer => '0',
                                     AstAccountUserAgent => '0',
                                     AstAccountFullContact => 'sip:0.0.0.0',
                                     objectClass => 'AsteriskVoicemail',
                                     AstContext => 'users',
                                     AstVoicemailMailbox => $extn,
                                     AstVoicemailPassword => $extn, #FIXME random?
                                     AstVoicemailEmail => $mail,
                                     AstVoicemailAttach => 'yes',
                                     AstVoicemailDelete => 'no',
                                     objectClass => 'AsteriskQueueMember',
                                     AstQueueMembername => $user,
                                     AstQueueInterface => "SIP/$user"
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

    my $result = $self->{ldap}->search(\%attrs);

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

    return { path => '/asterisk/user.mas',
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

    my $asterisk = $self->{asterisk};
    return unless ($asterisk->configured());

    $self->_removeVoicemail($user);

    my $extensions = new EBox::Asterisk::Extensions;
    $extensions->delUserExtension($user);

    my $users = EBox::Global->modInstance('users');
    my $ldap = $users->{ldap};
    my $dn = "uid=$user," . $users->usersDn;

    $ldap->delObjectclass($dn, 'AsteriskSIPUser');
    $ldap->delObjectclass($dn, 'AsteriskVoiceMail');
    $ldap->delObjectclass($dn, 'AsteriskQueueMember');
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


sub _delGroup
{
    my ($self, $group) = @_;

    my $asterisk = $self->{asterisk};
    return unless ($asterisk->configured());

    my $extensions = new EBox::Asterisk::Extensions;

    my @users = $self->asteriskUsersInQueue($group);
    foreach my $user (@users) {
        $extensions->delQueueMember($user, $group);
    }

    $extensions->delQueue($group) if $self->hasQueue($group);
}


sub _groupAddOns
{
    my ($self, $group) = @_;

    my $asterisk = $self->{asterisk};
    return unless ($asterisk->configured());

    my $active = 'no';
    $active = 'yes' if ($self->hasQueue($group));

    my $extensions = new EBox::Asterisk::Extensions;
    my $extn = $extensions->getQueueExtension($group);

    my $args = {
        'nacc' => scalar ($self->asteriskUsersInQueue($group)),
        'group' => $group,
        'extension' => $extn,
        'active'   => $active,
        'service' => $asterisk->isEnabled(),
    };

    return { path => '/asterisk/group.mas',
             params => $args };
}


sub _modifyGroup
{
    my ($self, $group, %params) = @_;

    my $asterisk = $self->{asterisk};
    return unless ($asterisk->configured());

    return unless $self->hasQueue($group);

    return unless (any($self->asteriskUsersInQueue($group)) eq $params{'user'});

    my $extensions = new EBox::Asterisk::Extensions;

    if ( $params{'op'} eq 'del' ) {
        $extensions->delQueueMember($params{'user'}, $group);
    }

    if ( $params{'op'} eq 'add' ) {
        $extensions->addQueueMember($params{'user'}, $group);
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

    defined $option or $option = 0;

    my $hasAccount = $self->hasAccount($username);

    ($hasAccount xor $option) or return;

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


sub hasQueue
{
    my ($self, $group) = @_;

    my $extensions = new EBox::Asterisk::Extensions;

    my $ldap = $self->{ldap};

    my %attrs = (
                 base => $extensions->queuesDn,
                 filter => "&(objectClass=AsteriskQueue)(AstQueueName=$group)",
                 scope => 'one'
                );

    my $result = $ldap->search(\%attrs);

    return ($result->count > 0);
}


sub setHasQueue
{
    my ($self, $group, $option) = @_;

    my $extensions = new EBox::Asterisk::Extensions;

    defined $option or $option = 0;

    my $hasQueue = $self->hasQueue($group);

    ($hasQueue xor $option) or return;

    if ($option) {
        $self->genQueue($group);
    } else {
        $self->_delGroup($group);
    }
}


sub genQueue
{
    my ($self, $group) = @_;

    my $asterisk = $self->{asterisk};
    return unless ($asterisk->configured());

    my $extensions = new EBox::Asterisk::Extensions;

    my $extn = $extensions->firstFreeExtension($extensions->QUEUEMINEXTN, $extensions->QUEUEMAXEXTN);
    $extensions->addQueueExtension($group, $extn);

    $extensions->addQueue($group);

    my @users = $self->asteriskUsersInQueue($group);
    foreach my $user (@users) {
        $extensions->addQueueMember($user, $group);
    }
}


sub asteriskUsersInQueue
{
    # XXX not very nice design but i try to make it fast
    my ($self, $group) = @_;

    my $users = EBox::Global->modInstance('users');

    my %args = (
                base => $users->usersDn,
                filter => 'objectclass=AsteriskSIPUser',
                scope => 'one',
               );

    my $result = $self->{ldap}->search(\%args);

    my @asteriskusers;
    foreach my $entry ($result->entries()) {
        push @asteriskusers, $entry->get_value('uid');
    }

    my $anyUserInGroup = any( @{ $users->usersInGroup($group) } );

    # the intersection between users with asterisk account and users of the group
    my @asteriskusersingroup = grep {
        $_ eq $anyUserInGroup
    } @asteriskusers;

    return @asteriskusersingroup;
}


sub schemas
{
    return [ EBox::Config::share() . '/ebox-asterisk/asterisk.ldif' ];
}


sub acls
{
    my ($self) = @_;

    return [
        "to attrs=AstVoicemailPassword, AstVoicemailEmail," .
        "AstVoicemailAttach, AstVoicemailDelete" .
        "by dn.regex=\"" . $self->{ldap}->rootDn() . "\" write " .
        "by self write " .
        "by * none" ];
}


# Method: defaultUserModel
#
#   Overrides <EBox::UsersAndGrops::LdapUserBase::defaultUserModel>
#   to return our default user template.
#
sub defaultUserModel
{
    return 'asterisk/AsteriskUser';
}

1;
