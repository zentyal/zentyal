# Copyright (C) 2010-2012 eBox Technologies S.L.
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
use Perl6::Junction qw(any);

sub new
{
    my $class = shift;
    my $self  = {};
    $self->{zarafa} = EBox::Global->modInstance('zarafa');
    bless($self, $class);
    return $self;
}

sub _userAddOns
{
    my ($self, $user) = @_;

    return unless ($self->{zarafa}->configured());

    my $active = 'no';
    $active = 'yes' if ($self->hasAccount($user));

    my $contact = 'no';
    $contact = 'yes' if ($self->hasContact($user));

    my $is_admin = 0;
    $is_admin = 1 if ($self->isAdmin($user));

    my @args;
    my $args = {
        'user' => $user,
        'active'   => $active,
        'is_admin' => $is_admin,
        'contact' => $contact,
        'service' => $self->{zarafa}->isEnabled(),
    };

    return { path => '/zarafa/zarafa.mas', params => $args };
}

sub schemas
{
    return [ EBox::Config::share() . 'zentyal-zarafa/zarafa.ldif' ]
}

sub indexes
{
    return [ 'zarafaAccount' ];
}


sub isAdmin
{
    my ($self, $user) = @_;

    return ($user->get('zarafaAdmin') eq 1);
}

sub setIsAdmin
{
    my ($self, $user, $option) = @_;
    my $global = EBox::Global->getInstance(1);

    return unless ($self->isAdmin($user) xor $option);

    $user->set('isAdmin', $option);
}

sub hasAccount
{
    my ($self, $user) = @_;

    return ('zarafa-user' eq any $user->get('objectClass'));
}

sub setHasAccount
{
    my ($self, $user, $option) = @_;

    if (not $self->hasAccount($user) and $option) {

        $self->setHasContact($user, 0);
        $user->add('objectClass', [ 'zarafa-user', 'zarafa-contact' ], 1);
        $user->set('zarafaAccount', 1, 1);
        $user->set('zarafaAdmin', 0, 1);
        $user->set('zarafaQuotaOverride', 0, 1);
        $user->set('zarafaQuotaWarn', 0, 1);
        $user->set('zarafaQuotaSoft', 0, 1);
        $user->set('zarafaQuotaHard', 0, 1);
        $user->save();

        $self->{zarafa}->_hook('setacc', $user->name());

    } elsif ($self->hasAccount($user) and not $option)) {

        $user->remove('objectClass', [ 'zarafa-user', 'zarafa-contact' ], 1);
        $user->delete('zarafaAccount', 1);
        $user->delete('zarafaAdmin', 1);
        $user->delete('zarafaQuotaOverride', 1);
        $user->delete('zarafaQuotaWarn', 1);
        $user->delete('zarafaQuotaSoft', 1);
        $user->delete('zarafaQuotaHard', 1);
        $user->save();

        my $model = EBox::Model::ModelManager::instance()->model('zarafa/ZarafaUser');
        $self->setHasContact($user, $model->contactValue());

        $self->{zarafa}->_hook('unsetacc', $user->name());
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
   $self->setHasContact($user, $model->contactValue());
}

sub hasContact
{
    my ($self, $user) = @_;

    return ('zarafa-contact' eq any $user->get('objectClass'));
}

sub setHasContact
{
    my ($self, $user, $option) = @_;

    if ($self->hasContact($user) and not $option) {
        $user->remove('objectClass', 'zarafa-contact');
    }
    elsif (not $self->hasContact($user) and $option) {
        $user->add('objectClass', 'zarafa-contact');
    }

    return 0;
}

sub _delUserWarning
{
    my ($self, $user) = @_;

    return unless ($self->{zarafa}->configured());

    $self->hasAccount($user) or
        return;

    my $txt = __('This user has a Zarafa account. If the user is currently connected it will continue connected until Zarafa authorization is again required.');

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
