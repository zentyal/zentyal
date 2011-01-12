# Copyright (C) 2010 eBox Technologies S.L.
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

package EBox::ZarafaLdapUser;

use base qw(EBox::LdapUserBase);

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Config;
use EBox::Ldap;
use EBox::UsersAndGroups;
use EBox::Model::ModelManager;

sub new
{
    my $class = shift;
    my $self  = {};
    $self->{ldap} = EBox::Ldap->instance();
    $self->{zarafa} = EBox::Global->modInstance('zarafa');
    bless($self, $class);
    return $self;
}

sub _userAddOns
{
    my ($self, $username) = @_;

    return unless ($self->{zarafa}->configured());

    my $active = 'no';
    $active = 'yes' if ($self->hasAccount($username));

    my $contact = 'no';
    $contact = 'yes' if ($self->hasContact($username));

    my $is_admin = 0;
    $is_admin = 1 if ($self->isAdmin($username));

    my @args;
    my $args = {
                    'username' => $username,
                    'active'   => $active,
                    'is_admin' => $is_admin,
                    'contact' => $contact,

                    'service' => $self->{zarafa}->isEnabled(),
           };

    return { path => '/zarafa/zarafa.mas',
         params => $args };
}

sub schemas
{
    return [ EBox::Config::share() . 'ebox-zarafa/zarafa.ldif' ]
}

sub localAttributes
{
    my @attrs = qw(zarafaAccount zarafaAdmin zarafaQuotaOverride zarafaQuotaWarn zarafaQuotaSoft zarafaQuotaHard);
    return \@attrs;
}


sub indexes
{
    return [ 'zarafaAccount' ];
}


sub isAdmin #($username)
{
    my ($self, $username) = @_;
    my $global = EBox::Global->getInstance(1);
    my $users = $global->modInstance('users');
    my $dn = $users->usersDn;
    my $active = '';
    my $is_admin = 0;

    $users->{ldap}->ldapCon;
    my $ldap = $users->{ldap};

    my %args = (base => $dn,
        filter => "uid=$username");
    my $mesg = $ldap->search(\%args);

    if ($mesg->count != 0) {
        foreach my $item (@{$mesg->entry->{'asn'}->{'attributes'}}) {
        return 1 if (($item->{'type'} eq 'zarafaAdmin') &&
            (shift(@{$item->{'vals'}}) eq '1'));
    }
    }
    return 0;
}

sub setIsAdmin #($username, [01]) 0=disable, 1=enable
{
        my ($self, $username, $option) = @_;
    my $global = EBox::Global->getInstance(1);

    return unless ($self->isAdmin($username) xor $option);

    my $users = $global->modInstance('users');
    my $dn = "uid=$username,".$users->usersDn;

    $users->{ldap}->ldapCon;
    my $ldap = $users->{ldap};

    my %args = (base => $dn,
            filter => "uid=$username");
    my $mesg = $ldap->search(\%args);

    if ($mesg->count != 0){
        if ($option){
        my %attrs = (
              changes => [
                   replace => [
                           'zarafaAdmin' => '1'
                           ]
                   ]
              );
        my $result = $ldap->modify($dn, \%attrs );
        ($result->is_error) and
            throw EBox::Exceptions::Internal('Error updating user: $username\n\n');
        } else {
            my %attrs = (
                  changes => [
                       replace => [
                               'zarafaAdmin' => '0'
                               ]
                       ]
                  );
        my $result = $ldap->modify($dn, \%attrs );
        ($result->is_error) and
            throw EBox::Exceptions::Internal('Error updating user: $username\n\n');
        }
    }

    return 0;
}

sub hasAccount #($username)
{
    my ($self, $username) = @_;
    my $global = EBox::Global->getInstance(1);
    my $users = $global->modInstance('users');
    my $dn = $users->usersDn;

    $users->{ldap}->ldapCon;
    my $ldap = $users->{ldap};

    my %args = (base => $dn,
                filter => "&(objectClass=zarafa-user)(uid=$username)");
    my $mesg = $ldap->search(\%args);

    return 1 if ($mesg->count != 0);
    return 0;
}

sub setHasAccount #($username, [01]) 0=disable, 1=enable
{
    my ($self, $username, $option) = @_;
    my $global = EBox::Global->getInstance(1);
    my $users = $global->modInstance('users');
    my $dn = "uid=$username," . $users->usersDn;

    $users->{ldap}->ldapCon;
    my $ldap = $users->{ldap};

    my %args = (base => $dn,
            filter => "&(objectClass=zarafa-user)");
    my $mesg = $ldap->search(\%args);

    if (!$mesg->count and ($option)) {
        my %attrs = (
              changes => [
                       add => [
                           'objectClass' => 'zarafa-user',
                           'zarafaAccount' => '1',
                           'zarafaAdmin' => '0',
                           'zarafaQuotaOverride' => '0',
                           'zarafaQuotaWarn' => '0',
                           'zarafaQuotaSoft' => '0',
                           'zarafaQuotaHard' => '0',
                           ]
                       ]
              );
        my $result = $ldap->modify($dn, \%attrs );
        ($result->is_error) and
        throw EBox::Exceptions::Internal('Error updating user: $username\n\n');

        $self->setHasContact($username, 0);

        $self->{zarafa}->_hook('setacc', $username);

    } elsif ($mesg->count and not ($option)) {
        my %attrs = (
              changes => [
                       delete => [
                          'objectClass' => ['zarafa-user'],
                              'zarafaAccount' => [],
                              'zarafaAdmin' => [],
                              'zarafaQuotaOverride' => [],
                              'zarafaQuotaWarn' => [],
                              'zarafaQuotaSoft' => [],
                              'zarafaQuotaHard' => [],
                          ]
                       ]
              );
        my $result = $ldap->modify($dn, \%attrs );
        ($result->is_error) and
        throw EBox::Exceptions::Internal('Error updating user: $username\n\n');

        my $model = EBox::Model::ModelManager::instance()->model('zarafa/ZarafaUser');
        $self->setHasContact($username, $model->contactValue());

        $self->{zarafa}->_hook('unsetacc', $username);
    }

    return 0;
}

sub _addUser
{
   my ($self, $user, $password) = @_;

   unless ($self->{zarafa}->configured()) {
       return;
   }
   my $model = EBox::Model::ModelManager::instance()->model('zarafa/ZarafaUser');
   $self->setHasAccount($user, $model->enabledValue());
}

sub hasContact #($username)
{
    my ($self, $username) = @_;
    my $global = EBox::Global->getInstance(1);
    my $users = $global->modInstance('users');
    my $dn = $users->usersDn;

    $users->{ldap}->ldapCon;
    my $ldap = $users->{ldap};

    my %args = (base => $dn,
                filter => "&(objectClass=zarafa-contact)(uid=$username)");
    my $mesg = $ldap->search(\%args);

    return 1 if ($mesg->count != 0);
    return 0;
}

sub setHasContact #($username, [01]) 0=disable, 1=enable
{
    my ($self, $username, $option) = @_;
    my $global = EBox::Global->getInstance(1);
    my $users = $global->modInstance('users');
    my $dn = "uid=$username," . $users->usersDn;

    $users->{ldap}->ldapCon;
    my $ldap = $users->{ldap};

    my %args = (base => $dn,
                filter => "&(objectClass=zarafa-contact)");
    my $mesg = $ldap->search(\%args);

    if (!$mesg->count and ($option)) {
        my %attrs = (
              changes => [
                       add => [
                           'objectClass' => 'zarafa-contact',
                           ]
                       ]
              );
        my $result = $ldap->modify($dn, \%attrs );
        ($result->is_error) and
        throw EBox::Exceptions::Internal('Error updating user: $username\n\n');
    } elsif ($mesg->count and not ($option)) {
        my %attrs = (
              changes => [
                       delete => [
                          'objectClass' => ['zarafa-contact'],
                          ]
                       ]
              );
        my $result = $ldap->modify($dn, \%attrs );
        ($result->is_error) and
        throw EBox::Exceptions::Internal('Error updating user: $username\n\n');
    }

    return 0;
}

sub _delUserWarning
{
    my ($self, $user) = @_;

    return unless ($self->{zarafa}->configured());

    $self->hasAccount($user) or
        return;

    settextdomain('ebox-zarafa');
    my $txt = __('This user has a Zarafa account. If the user is currently connected it will continue connected until Zarafa authorization is again required.');
    settextdomain('ebox-usersandgroups');

    return $txt;
}

# Method: defaultUserModel
#
#   Overrides <EBox::UsersAndGrops::LdapUserBase::defaultUserModel>
#   to return our default user template
#
sub defaultUserModel
{
    return 'zarafa/ZarafaUser';
}

1;
