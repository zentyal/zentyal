# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::CaptivePortal::LdapUser;

use base qw(EBox::LdapUserBase);

use EBox::Gettext;
use EBox::Global;
use EBox::Config;
use EBox::Ldap;
use EBox::Users;
use Perl6::Junction qw(any);

sub new
{
    my $class = shift;
    my $self  = {};
    $self->{ldap} = EBox::Ldap->instance();

    bless($self, $class);
    return $self;
}

sub _userAddOns
{
    my ($self, $user) = @_;

    my $cportal = EBox::Global->modInstance('captiveportal');
    return unless ($cportal->configured());

    my $overridden = $self->isQuotaOverridden($user);
    my $quota = $self->getQuota($user);
    my $limitBW = $cportal->model('BWSettings')->limitBWValue();

    my @args;
    my $args = {
        'user'       => $user,
        'overridden' => $overridden,
        'quota'      => $quota,
        'service'    => $cportal->isEnabled(),
        'liimitBW'    => $limitBW,
    };

    return {
        title =>  __('Captive Portal'),
        path => '/captiveportal/useraddon.mas',
        params => $args
       };
}

sub noMultipleOUSupportComponent
{
    my ($self) = @_;
    return $self->standardNoMultipleOUSupportComponent(__('Captive Portal'));
}

sub isQuotaOverridden
{
    my ($self, $user) = @_;

    if ($user->get('captiveQuotaOverride') eq 'TRUE') {
        return 1;
    }
    return 0;
}

# Method: setQuota
#
#   Configures user quota, if overrides default configured quota
#   a second parameters is needed. Quota in Mb. If not, default quota
#   will be used.
#
#   Parameters:
#       - username
#       - override default?
#       - overridden quota in Mb
#
sub setQuota
{
    my ($self, $user, $overridden, $quota) = @_;

    # Quota parameter is optional if it's not overridden
    unless ($overridden) {
        $quota = 0;
    }

    # Convert to LDAP format
    $overridden = $overridden ? 'TRUE' : 'FALSE';

    my $alreadyHasClass = grep {
        $_ eq 'captiveUser'
    } $user->get('objectClass');
    if (not $alreadyHasClass) {
        # Due to a bug in Samba4 we cannot update an objectClass and its attributes at the same time
        $user->add('objectClass', 'captiveUser');
        $user->clearCache();
    }

    $user->set('captiveQuotaOverride', $overridden, 1);
    $user->set('captiveQuota', $quota, 1);
    $user->save();

    return 0;
}

# Method: getQuota
#
#   Returns quota in Mb for the given user, it will depend on
#   default settings or overriden ones.
#
#   0 means unlimited.
#
#   Parameters:
#       - username
#
sub getQuota
{
    my ($self, $user) = @_;

    my $captiveQuotaOverride =  $user->get('captiveQuotaOverride');
    if ((defined $captiveQuotaOverride) and ($captiveQuotaOverride eq 'TRUE')) {
        return $user->get('captiveQuota');
    }

    my $global = EBox::Global->getInstance(1);
    my $cportal = $global->modInstance('captiveportal');
    my $model = $cportal->model('BWSettings');

    return $model->defaultQuotaValue();
}

sub _addUser
{
    my ($self, $user, $password) = @_;

    my $captiveportal = EBox::Global->modInstance('captiveportal');

    return unless ($captiveportal->configured());

    my $model = $captiveportal->model('CaptiveUser');
    my $row = $model->row();
    my $defaultQuota = $row->elementByName('defaultQuota');

    if ($defaultQuota->selectedType() eq 'defaultQuota_default') {
        $self->setQuota($user, 0);
    } else {
        my $quota = 0;
        if ($defaultQuota->selectedType() eq 'defaultQuota_size') {
            $quota = $defaultQuota->value();
        }
        $self->setQuota($user, 1, $quota);
    }
}

# Method: defaultUserModel
#
#   Overrides <EBox::UsersAndGrops::LdapUserBase::defaultUserModel>
#   to return our default user template
#
sub defaultUserModel
{
    return 'captiveportal/CaptiveUser';
}

sub _delGroup
{
     my ($self, $group) = @_;
     $group = $group->name();
     if ($group ne $self->_authGroup()) {
         return;
     }

     my $captive = EBox::Global->modInstance('captiveportal');
     $captive->model('Settings')->setAuthGroupToAll();
     $captive->enableService(0);
}

sub _delGroupWarning
{
    my ($self, $group) = @_;
    $group = $group->name();
    if ($group eq $self->_authGroup()) {
        return (__('Captive portal authorized group. The module will be disabled'))
    } else {
        return ();
    }
}

sub _authGroup
{
    my $captive = EBox::Global->modInstance('captiveportal');
    my $settings = $captive->model('Settings');
    return  $settings->groupValue();
}

1;
