# Copyright (C) 2005-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::JabberLdapUser;

use base qw(EBox::LdapUserBase);

use EBox::Gettext;
use EBox::Global;
use EBox::Config;
use EBox::Ldap;
use EBox::Samba;
use EBox::Samba::User;
use EBox::Model::Manager;

sub new
{
    my $class = shift;
    my $self  = {};
    $self->{ldap} = EBox::Ldap->instance();
    $self->{jabber} = EBox::Global->modInstance('jabber');
    bless($self, $class);
    return $self;
}

sub _userAddOns
{
    my ($self, $user) = @_;

    my $jabber = $self->{jabber};
    return unless $jabber->configured();

    my $state = $jabber->get_state();
    return unless $state->{_schemasAdded};

    my $active   = $self->hasAccount($user) ? 1 : 0;
    my $is_admin = $self->isAdmin($user) ? 1 : 0;

    my @args;
    my $args = {
            'user'     => $user,
            'active'   => $active,
            'is_admin' => $is_admin,
            'service'  => $self->{jabber}->isEnabled(),
           };

    return {
        title =>  __('Jabber account'),
        path => '/jabber/jabber.mas',
        params => $args
       };
}

sub noMultipleOUSupportComponent
{
    my ($self) = @_;
    return $self->standardNoMultipleOUSupportComponent(__('Jabber Account'));
}

sub isAdmin
{
    my ($self, $user) = @_;

    return ($user->get('jabberAdmin') eq 'TRUE');
}

sub setIsAdmin
{
    my ($self, $user, $option) = @_;

    if ($option){
        $user->set('jabberAdmin', 'TRUE');
    } else {
        $user->set('jabberAdmin', 'FALSE');
    }
    my $global = EBox::Global->getInstance();
    $global->modChange('jabber');

    return 0;
}

sub hasAccount
{
    my ($self, $user) = @_;

    if ($user->get('jabberUid')) {
        return 1;
    }
    return 0;
}

sub setHasAccount
{
    my ($self, $user, $option) = @_;

    if ($self->hasAccount($user) and not $option) {
        my @objectclasses = $user->get('objectClass');
        @objectclasses = grep { $_ ne 'userJabberAccount' } @objectclasses;

        $user->delete('jabberUid', 1);
        $user->delete('jabberAdmin', 1);
        $user->set('objectClass',\@objectclasses, 1);
        $user->save();
    }
    elsif (not $self->hasAccount($user) and $option) {
        # Due to a bug in Samba4 we cannot update an objectClass and its attributes at the same time
        $user->add('objectClass', 'userJabberAccount');
        $user->clearCache();

        $user->add('jabberUid', $user->name(), 1);
        $user->add('jabberAdmin', 'FALSE', 1);
        $user->save();
    }

    return 0;
}

sub getJabberAdmins
{
    my $self = shift;

    my @admins = ();
    my $global = EBox::Global->getInstance();
    my $samba = $global->modInstance('samba');
    my $ldap = $samba->ldap();
    my $dse = $ldap->rootDse();
    my $defaultNC = $dse->get_value('defaultNamingContext');

    my $args = {
        base => $defaultNC,
        filter => '(jabberAdmin=TRUE)'
    };
    my $mesg = $ldap->search($args);

    foreach my $entry ($mesg->entries()) {
        push (@admins, new EBox::Samba::User(entry => $entry));
    }

    return \@admins;
}

sub _addUser
{
    my ($self, $user, $password) = @_;

    my $jabber = $self->{jabber};
    return unless $jabber->configured();

    my $state = $jabber->get_state();
    return unless $state->{_schemasAdded};

    my $model = $self->{jabber}->model('JabberUser');
    $self->setHasAccount($user, $model->enabledValue());
}

sub _delUserWarning
{
    my ($self, $user) = @_;

    return unless ($self->{jabber}->configured());

    $self->hasAccount($user) or return;

    my $txt = __('This user has a jabber account. If the user currently connected it will continue connected until jabber authorization is again required.');

    return $txt;
}

# Method: defaultUserModel
#
#   Overrides <EBox::UsersAndGrops::LdapUserBase::defaultUserModel>
#   to return our default user template
#
sub defaultUserModel
{
    return 'jabber/JabberUser';
}

1;
