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
use EBox::Model::Manager;
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

    my $has_pop3 = 0;
    $has_pop3 = 1 if ($self->hasFeature($user, 'pop3'));

    my $has_imap = 0;
    $has_imap = 1 if ($self->hasFeature($user, 'imap'));

    my $is_admin = 0;
    $is_admin = 1 if ($self->isAdmin($user));

    my $is_store = 0;
    $is_store = 1 if ($self->isStore($user));

    my $has_meeting_autoaccept = 0;
    $has_meeting_autoaccept = 1 if ($self->hasMeetingAutoaccept($user));

    my $has_meeting_declineconflict = 0;
    $has_meeting_declineconflict = 1 if ($self->hasMeetingDeclineConflict($user));

    my $has_meeting_declinerecurring = 0;
    $has_meeting_declinerecurring = 1 if ($self->hasMeetingDeclineRecurring($user));

    my @args;
    my $args = {
        'user' => $user,
        'active'   => $active,
        'has_pop3' => $has_pop3,
        'has_imap' => $has_imap,
        'is_admin' => $is_admin,
        'is_store' => $is_store,
        'meeting_autoaccept' => $has_meeting_autoaccept,
        'meeting_declineconflict' => $has_meeting_declineconflict,
        'meeting_declinerecurring' => $has_meeting_declinerecurring,
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

sub hasFeature
{
    my ($self, $user, $feature) = @_;

    my @enabled = split(/ /, $user->get('zarafaEnabledFeatures'));
    return ($feature eq any @enabled);
}

sub setHasFeature
{
    my ($self, $user, $feature, $option) = @_;
    my $global = EBox::Global->getInstance(1);

    return unless ($self->hasFeature($user, $feature) xor $option);

    my $new = $feature . " " . $user->get('zarafaEnabledFeatures');
    $new =~ s/\s+$//;
    $user->set('zarafaEnabledFeatures', $new);
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

    $user->set('zarafaAdmin', $option);
}

sub isStore
{
    my ($self, $user) = @_;

    return ($user->get('zarafaSharedStoreOnly') eq 1);
}

sub setIsStore
{
    my ($self, $user, $option) = @_;
    my $global = EBox::Global->getInstance(1);

    return unless ($self->isStore($user) xor $option);

    $user->set('zarafaSharedStoreOnly', $option);
}

sub hasMeetingAutoaccept
{
    my ($self, $user) = @_;

    return ($user->get('zarafaMrAccept') eq 1);
}

sub setMeetingAutoaccept
{
    my ($self, $user, $option) = @_;
    my $global = EBox::Global->getInstance(1);

    return unless ($self->hasMeetingAutoaccept($user) xor $option);

    $user->set('zarafaMrAccept', $option);
}

sub hasMeetingDeclineConflict
{
    my ($self, $user) = @_;

    return ($user->get('zarafaMrDeclineConflict') eq 1);
}

sub setMeetingDeclineConflict
{
    my ($self, $user, $option) = @_;
    my $global = EBox::Global->getInstance(1);

    return unless ($self->hasMeetingDeclineConflict($user) xor $option);

    $user->set('zarafaMrDeclineConflict', $option);
}

sub hasMeetingDeclineRecurring
{
    my ($self, $user) = @_;

    return ($user->get('zarafaMrDeclineRecurring') eq 1);
}

sub setMeetingDeclineRecurring
{
    my ($self, $user, $option) = @_;
    my $global = EBox::Global->getInstance(1);

    return unless ($self->hasMeetingDeclineRecurring($user) xor $option);

    $user->set('zarafaMrDeclineRecurring', $option);
}

sub hasAccount
{
    my ($self, $user) = @_;

    return ('zarafa-user' eq any $user->get('objectClass'));
}

sub setHasAccount
{
    my ($self, $user, $option) = @_;

    my $model = $self->{zarafa}->model('ZarafaUser');
    if (not $self->hasAccount($user) and $option) {
        $self->setHasContact($user, 0);
        $user->add('objectClass', [ 'zarafa-user', 'zarafa-contact' ], 1);
        $user->set('zarafaAccount', 1, 1);
        $user->set('zarafaAdmin', 0, 1);
        $user->set('zarafaSharedStoreOnly', 0, 1);
        $user->set('zarafaMrAccept', 0, 1);
        $user->set('zarafaMrDeclineConflict', 0, 1);
        $user->set('zarafaMrDeclineRecurring', 0, 1);
        $user->set('zarafaQuotaOverride', 0, 1);
        $user->set('zarafaQuotaWarn', 0, 1);
        $user->set('zarafaQuotaSoft', 0, 1);
        $user->set('zarafaQuotaHard', 0, 1);
        $user->save();

        $self->setHasFeature($user, 'pop3', $model->pop3Value());
        $self->setHasFeature($user, 'imap', $model->imapValue());

        $self->{zarafa}->_hook('setacc', $user->name());
    } elsif ($self->hasAccount($user) and not $option) {
        $user->remove('objectClass', [ 'zarafa-user', 'zarafa-contact' ], 1);
        $user->delete('zarafaAccount', 1);
        $user->delete('zarafaAdmin', 1);
        $user->delete('zarafaSharedStoreOnly', 1);
        $user->delete('zarafaMrAccept', 1);
        $user->delete('zarafaMrDeclineConflict', 1);
        $user->delete('zarafaMrDeclineRecurring', 1);
        $user->delete('zarafaQuotaOverride', 1);
        $user->delete('zarafaQuotaWarn', 1);
        $user->delete('zarafaQuotaSoft', 1);
        $user->delete('zarafaQuotaHard', 1);
        $user->save();

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
   my $model = $self->{zarafa}->model('ZarafaUser');

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

# Method: multipleOUSupport
#
#   Returns 1 if this module supports users in multiple OU's,
#   0 otherwise
#
sub multipleOUSupport
{
    return 1;
}

1;
