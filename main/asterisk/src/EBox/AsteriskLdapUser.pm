# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::AsteriskLdapUser;

use base qw(EBox::LdapUserBase);

# Class: EBox::AsteriskLdapUser
#
#

use EBox::Gettext;
use EBox::Global;
use EBox::Ldap;
use EBox::Users;
use EBox::Users::User;
use EBox::Asterisk::Extensions;
use EBox::Model::Manager;

use Perl6::Junction qw(any);
use Digest::MD5 qw(md5_hex);

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
    my %params = @_;

    my $self  = {};
    $self->{ro} = $params{ro};
    $self->{ldap} = EBox::Ldap->instance();
    my $global  = EBox::Global->getInstance($self->{ro});
    $self->{asterisk} = $global->modInstance('asterisk');
    $self->{users}    = $global->modInstance('users');

    bless($self, $class);
    return $self;
}

# Group: Private methods

sub _genRealmHash
{
    my ($self, $user, $passwd) = @_;

    my $realm = $self->{asterisk}->ASTERISK_REALM;
    my $username = $user->name();
    my $digest = "$username:$realm:$passwd";
    return '{MD5}' . Digest::MD5::md5_hex($digest);
}

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
        my $model = $self->{asterisk}->model('AsteriskUser');
        return unless ($model->enabledValue());
    }

    my $extensions = new EBox::Asterisk::Extensions;

    my $extn = $extensions->firstFreeExtension();
    my $mail = $self->_getUserMail($user);

    my @objectclasses = $user->get('objectClass');

    unless ('AsteriskSIPUser' eq any(@objectclasses)) {
        $user->add('objectClass', ['AsteriskSIPUser',
                                   'AsteriskQueueMember',
                                   'AsteriskVoiceMail'], 1);

        my $md5secret = $self->_genRealmHash($user, $passwd);
        $user->set('AstMD5secret', $md5secret, 1);
        $user->set('AstAccountType', 'friend', 1);
        $user->set('AstAccountContext', 'users',1);
        $user->set('AstAccountCallerID', $extn, 1);
        $user->set('AstAccountMailbox', $extn, 1);
        $user->set('AstAccountHost', 'dynamic', 1);
        $user->set('AstAccountNAT', 'yes', 1);
        $user->set('AstAccountQualify', 'yes', 1);
        $user->set('AstAccountCanReinvite', 'no', 1);
        $user->set('AstAccountDTMFMode', 'rfc2833', 1);
        $user->set('AstAccountInsecure', 'port', 1);
        $user->set('AstAccountLastQualifyMilliseconds', '0', 1);
        $user->set('AstAccountIPAddress', '0.0.0.0', 1);
        $user->set('AstAccountPort', '0', 1);
        $user->set('AstAccountExpirationTimestamp', '0', 1);
        $user->set('AstAccountRegistrationServer', '0', 1);
        $user->set('AstAccountUserAgent', '0', 1);
        $user->set('AstAccountFullContact', 'sip:0.0.0.0', 1);
        $user->set('AstContext', 'users', 1);
        $user->set('AstVoicemailMailbox', $extn, 1);
        $user->set('AstVoicemailPassword', $extn, 1);
        $user->set('AstVoicemailEmail', $mail, 1);
        $user->set('AstVoicemailAttach', 'yes', 1);
        $user->set('AstVoicemailDelete', 'no', 1);
        $user->set('AstQueueMembername', $user->name(), 1);
        $user->set('AstQueueInterface', 'SIP/' . $user->name(), 1);
        $user->save();

        if ($extn > 0) {
            $extensions->addUserExtension($user, $extn);
            my $global = EBox::Global->getInstance();
            $global->modChange('asterisk');
        }
    }
}

# FIXME doc
sub _getUserMail
{
    my ($self, $user) = @_;

    if ( $user->get('mail') ) {
        return $user->get('mail');
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

    my $active = $self->hasAccount($user) ? 1 : 0;

    my $extensions = new EBox::Asterisk::Extensions;
    my $extn = $extensions->getUserExtension($user);

    my $args = {
        'user' => $user,
        'extension' => $extn,
        'active'   => $active,
        'service' => $asterisk->isEnabled(),
    };

    return {
              title =>  __('Asterisk account'),
              path => '/asterisk/user.mas',
              params => $args
          };
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

    my @objectclasses = $user->get('objectclass');
    @objectclasses = grep { $_ ne 'AsteriskSIPUser' } @objectclasses;
    @objectclasses = grep { $_ ne 'AsteriskVoiceMail' } @objectclasses;
    @objectclasses = grep { $_ ne 'AsteriskQueueMember' } @objectclasses;
    $user->set('objectclass', \@objectclasses, 1);
    $user->delete('AstMD5secret', 1);
    $user->delete('AstAccountType', 1);
    $user->delete('AstAccountContext', 1);
    $user->delete('AstAccountCallerID', 1);
    $user->delete('AstAccountMailbox', 1);
    $user->delete('AstAccountHost', 1);
    $user->delete('AstAccountNAT', 1);
    $user->delete('AstAccountQualify', 1);
    $user->delete('AstAccountCanReinvite', 1);
    $user->delete('AstAccountDTMFMode', 1);
    $user->delete('AstAccountInsecure', 1);
    $user->delete('AstAccountLastQualifyMilliseconds', 1);
    $user->delete('AstAccountIPAddress', 1);
    $user->delete('AstAccountPort', 1);
    $user->delete('AstAccountExpirationTimestamp', 1);
    $user->delete('AstAccountRegistrationServer', 1);
    $user->delete('AstAccountUserAgent', 1);
    $user->delete('AstAccountFullContact', 1);
    $user->delete('AstContext', 1);
    $user->delete('AstVoicemailMailbox', 1);
    $user->delete('AstVoicemailPassword', 1);
    $user->delete('AstVoicemailEmail', 1);
    $user->delete('AstVoicemailAttach', 1);
    $user->delete('AstVoicemailDelete', 1);
    $user->delete('AstQueueMembername', 1);
    $user->delete('AstQueueInterface', 1);
    $user->save();

    my $global = EBox::Global->getInstance();
    $global->modChange('asterisk');
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

sub _modifyUser
{
    my ($self, $user, $passwd) = @_;

    my $asterisk = $self->{asterisk};
    return unless ($asterisk->configured());

    return unless $self->hasAccount($user);
    return unless defined $passwd;

    my $md5secret = $self->_genRealmHash($user, $passwd);
    $user->set('AstMD5secret', $md5secret, 1);
    $user->save();
}

sub _delGroup
{
    my ($self, $group) = @_;

    my $asterisk = $self->{asterisk};
    return unless ($asterisk->configured());
    return unless $self->hasQueue($group);

    my $extensions = new EBox::Asterisk::Extensions;

    my @users = $self->asteriskUsersInQueue($group);
    foreach my $user (@users) {
        if ($extensions->isQueueMember($user, $group)) {
            $extensions->delQueueMember($user, $group);
        }
    }

    $extensions->delQueue($group);

    my $global = EBox::Global->getInstance();
    $global->modChange('asterisk');
}

sub _groupAddOns
{
    my ($self, $group) = @_;

    my $asterisk = $self->{asterisk};
    return unless ($asterisk->configured());

    my $active = $self->hasQueue($group) ? 1 : 0;
    my $extensions = new EBox::Asterisk::Extensions;
    my $extn = $extensions->getQueueExtension($group);

    my $args = {
        'group' => $group,
        'extension' => $extn,
        'active'   => $active,
        'service' => $asterisk->isEnabled(),
    };

    return {
        title  =>  __('Asterisk group queue'),
        path   => '/asterisk/group.mas',
        params => $args
       };
}

sub _modifyGroup
{
    my ($self, $group, %params) = @_;
    my $user = $params{user};
    my $op   = $params{op};

    my $asterisk = $self->{asterisk};
    return unless ($asterisk->configured());
    return unless $self->hasQueue($group);

    my $extensions = new EBox::Asterisk::Extensions;
    return unless $self->hasAccount($user);
    my $queueMember =  $extensions->isQueueMember($user,   $group);

    if ( $op eq 'del' ) {
        return if not $queueMember;
        $extensions->delQueueMember($user, $group);
    } elsif ( $op eq 'add' ) {
        return if $queueMember;
        $extensions->addQueueMember($user, $group);
    }

    my $global = EBox::Global->getInstance();
    $global->modChange('asterisk');
}

# Method: setHasAccount
#
#       Enable or disable the Asterisk account for this user. The way it's
#       implementated this method actually create or delete the account.
#
# Parameters:
#
#       user - user object of the action
#       enable - 0=disable, 1=enable the account
#
sub setHasAccount
{
    my ($self, $user, $enable) = @_;
    defined $enable or $enable = 0;

    my $hasAccount = $self->hasAccount($user);

    ($hasAccount xor $enable) or return;

    if ($enable) {
        $self->_addUser($user, undef, 1);
    } else {
        $self->_delUser($user);
    }

    my $extensions = new EBox::Asterisk::Extensions;
    # add or remove user to groups queues
    foreach my $group (@{$user->groups()})    {
        next unless $self->hasQueue($group);
        my $isInQueue = $extensions->isQueueMember($user, $group);
        if ($enable and not $isInQueue) {
            $extensions->addQueueMember($user, $group);
        } elsif (not $enable and $isInQueue) {
            $extensions->delQueueMember($user, $group);
        }
    }
}

# Method: hasAccount
#
#       Check if the user has an Asterisk account
#
# Parameters:
#
#       user - user object of the action
#
# Returns:
#
#       boolean - true if it exists, otherwise false
#
sub hasAccount
{
    my ($self, $user) = @_;

    my @objectclasses = $user->get('objectClass');

    return ('AsteriskSIPUser' eq any @objectclasses);
}

sub hasQueue
{
    my ($self, $group) = @_;

    my $extensions = new EBox::Asterisk::Extensions;

    my $ldap = $self->{ldap};

    my $groupname = $group->get('cn');
    my %attrs = (
                 base => $extensions->queuesDn,
                 filter => "&(objectClass=AsteriskQueue)(AstQueueName=$groupname)",
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

    my $global = EBox::Global->getInstance();
    $global->modChange('asterisk');
}

sub asteriskUsersInQueue
{
    my ($self, $group) = @_;

    my $usersContainer = EBox::Users::User->defaultContainer();
    my $groupdn = $group->dn();

    my %args = (
                base => $usersContainer->dn(),
                filter => "(&(objectclass=AsteriskSIPUser)(memberOf=$groupdn))",
                scope => 'one',
               );

    my $result = $self->{ldap}->search(\%args);

    my @asteriskusers;
    foreach my $entry ($result->entries()) {
        push (@asteriskusers, new EBox::Users::User(entry => $entry));
    }

    return @asteriskusers;
}

sub schemas
{
    return [ EBox::Config::share() . '/zentyal-asterisk/asterisk.ldif' ];
}

sub acls
{
    my ($self) = @_;

    return [
        "to attrs=AstVoicemailPassword,AstVoicemailEmail," .
        "AstVoicemailAttach,AstVoicemailDelete,AstMD5secret " .
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

# Method: hiddenOUs
#
#   Returns the list of OUs to hide on the UI
#
sub hiddenOUs
{
    return [ 'Extensions', 'Queues' ];
}

1;
