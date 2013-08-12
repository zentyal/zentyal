# Copyright (C) 2010-2013 Zentyal S.L.
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

package EBox::ZarafaLdapUser;

use base qw(EBox::LdapUserBase);

use EBox::Gettext;
use EBox::Global;
use EBox::Config;
use EBox::Ldap;
use EBox::Users;
use EBox::Model::Manager;
use Perl6::Junction qw(any all);

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

    my $active = $self->hasAccount($user) ? 1 : 0;
    my $contact = $self->hasContact($user)? 1 : 0;
    my $has_pop3 = $self->hasFeature($user, 'pop3') ? 1 : 0;
    my $has_imap = $self->hasFeature($user, 'imap') ? 1 : 0;
    my $is_admin = $self->isAdmin($user) ? 1 : 0;

    my $has_meeting_autoaccept = $self->hasMeetingAutoaccept($user) ? 1 : 0;
    my $has_meeting_declineconflict = $self->hasMeetingDeclineConflict($user) ? 1 : 0;
    my $has_meeting_declinerecurring = $self->hasMeetingDeclineRecurring($user) ? 1 : 0;

    my $args = {
        'user' => $user,
        'active'   => $active,
        'has_pop3' => $has_pop3,
        'has_imap' => $has_imap,
        'is_admin' => $is_admin,

        'meeting_autoaccept' => $has_meeting_autoaccept,
        'meeting_declineconflict' => $has_meeting_declineconflict,
        'meeting_declinerecurring' => $has_meeting_declinerecurring,

        'contact' => $contact,

        'service' => $self->{zarafa}->isEnabled(),
    };

    return {
        title =>   __('Zarafa account'),
        path => '/zarafa/zarafa.mas',
        params => $args
       };
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

    my @features = $user->get('zarafaEnabledFeatures');
    my $hasFeature = grep { $_ eq $feature } @features;
    return $hasFeature;
}

sub setHasFeature
{
    my ($self, $user, $feature, $option) = @_;

    my @features = $user->get('zarafaEnabledFeatures');
    my %enabled = map { $_ => 1 } @features;

    if ($option) {
        $enabled{$feature} = 1;
    } else {
        delete $enabled{$feature};
    }

    @features = keys (%enabled);
    if (@features) {
        $user->set('zarafaEnabledFeatures', \@features);
    } else {
        $user->delete('zarafaEnabledFeatures');
    }
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
    my $username = $user->name();
    my $cmd = "zarafa-admin -u $username --mr-accept $option";
    EBox::Sudo::rootWithoutException($cmd);
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
    my $username = $user->name();
    my $cmd = "zarafa-admin -u $username --mr-decline-conflict $option";
    EBox::Sudo::rootWithoutException($cmd);
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
    my $username = $user->name();
    my $cmd = "zarafa-admin -u $username --mr-decline-recurring $option";
    EBox::Sudo::rootWithoutException($cmd);
}

sub hasAccount
{
    my ($self, $user) = @_;
    unless ('zarafa-user' eq any($user->get('objectClass'))) {
        return 0;
    }
    return not $user->get('zarafaSharedStoreOnly');
}

sub setHasAccount
{
    my ($self, $user, $enable) = @_;

    my $hasAccount =  $self->hasAccount($user);
    if ((not $hasAccount) and $enable) {
        my $anyObjectClass = any($user->get('objectClass'));
        my $hasClass = 'zarafa-user' eq $anyObjectClass;
        my $hasContactClass = 'zarafa-contact' eq $anyObjectClass;

        if ($hasClass) {
            $user->set('zarafaSharedStoreOnly', 0);
            if (not $hasContactClass) {
                $user->add('objectClass', ['zarafa-contact'], 1);
            }
        } else {
            my @toAdd = ('zarafa-user');
            push @toAdd, 'zarafa-contact' if not $hasContactClass;
            $user->add('objectClass', \@toAdd, 1);

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
        }

        my $model = $self->{zarafa}->model('ZarafaUser');
        $self->setHasFeature($user, 'pop3', $model->pop3Value());
        $self->setHasFeature($user, 'imap', $model->imapValue());

        $self->{zarafa}->_hook('setacc', $user->name());

    } elsif ($hasAccount and not $enable) {
        $user->set('zarafaSharedStoreOnly', 1);
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
   my $enabledValue = $model->enabledValue();
   if ($enabledValue) {
       $self->setHasAccount($user, 1);
   } else {
       $self->setHasContact($user, $model->contactValue());
   }

}

sub _addContact
{
    my ($self, $contact) = @_;

    unless ($self->{zarafa}->configured()) {
        return;
    }

    $self->setHasContact($contact, 1);
}

sub hasContact
{
    my ($self, $person) = @_;
    return 'zarafa-contact' eq any($person->get('objectClass'));
}

sub setHasContact
{
    my ($self, $person, $contact) = @_;

    if ($self->hasAccount($person)) {
        # nothing to do here
        return;
    }

    my $alreadyContact = $self->hasContact($person);
    if ($alreadyContact and not $contact) {
        $person->remove('objectClass', 'zarafa-contact');
    }
    elsif (not $alreadyContact and $contact) {
        $person->add('objectClass', 'zarafa-contact');
    }

    return 0;
}

sub _delUserWarning
{
    my ($self, $user) = @_;

    return unless ($self->{zarafa}->configured());

    $self->hasAccount($user) or
        return;

    my $txt = __('This user has a Zarafa account (if the user is currently connected it will continue connected until Zarafa authorization is again required).');

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

# Method: hiddenOUs
#
#   Returns the list of OUs to hide on the UI
#
sub hiddenOUs
{
    return [ 'zarafa' ];
}

1;
