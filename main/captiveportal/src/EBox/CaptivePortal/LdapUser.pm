# Copyright (C) 2011 eBox Technologies S.L.
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

package EBox::CaptivePortal::LdapUser;

use base qw(EBox::LdapUserBase);

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Config;
use EBox::Ldap;
use EBox::UsersAndGroups;

sub new
{
    my $class = shift;
    my $self  = {};
    $self->{ldap} = EBox::Ldap->instance();
    $self->{captiveportal} = EBox::Global->modInstance('captiveportal');
    bless($self, $class);
    return $self;
}

sub schemas
{
    return [ EBox::Config::share() . 'zentyal-captiveportal/captiveportal.ldif' ]
}

sub localAttributes
{
    my @attrs = qw(captiveQuotaOverride captiveQuota);
    return \@attrs;
}


#sub indexes
#{
#    return [ ];
#}


sub isQuotaOverridden
{
    my ($self, $username) = @_;
    my $users = EBox::Global->modInstance('users');
    my $dn = $users->usersDn;

    $users->{ldap}->ldapCon;
    my $ldap = $users->{ldap};

    my %args = (base => $dn,
        filter => "uid=$username");
    my $mesg = $ldap->search(\%args);

    if ($mesg->count != 0) {
        foreach my $item (@{$mesg->entry->{'asn'}->{'attributes'}}) {
            return 1 if (($item->{'type'} eq 'captiveQuotaOverride') and
                    (shift(@{$item->{'vals'}}) eq 'TRUE'));
        }
    }
    return 0;
}


sub setQuotaOverridden
{
    my ($self, $username, $overridden) = @_;
    my $global = EBox::Global->getInstance();

    # Convert to LDAP format
    $overridden = $overridden ? 'TRUE' : 'FALSE';

    my $users = $global->modInstance('users');
    my $dn = "uid=$username,".$users->usersDn;

    $users->{ldap}->ldapCon;
    my $ldap = $users->{ldap};

    my %args = (base => $dn,
            filter => "uid=$username");
    my $mesg = $ldap->search(\%args);

    if ($mesg->count == 0){
        my %attrs = (
              changes => [
                    add => [
                        'objectClass' => ['captiveUser'],
                        'captiveQuotaOverride' => $overridden,
                        'captiveQuota' => 0,
                        ]
                    ]
              );
        my $result = $ldap->modify($dn, \%attrs );

        if ($result->is_error) {
            throw EBox::Exceptions::Internal("Error updating user: $username\n\n");
        }
    } else {
        my %attrs = (
              changes => [
                   replace => [
                           'captiveQuotaOverride' => $overridden
                           ]
                   ]
              );
        my $result = $ldap->modify($dn, \%attrs );

        if ($result->is_error) {
            throw EBox::Exceptions::Internal("Error updating user: $username\n\n");
        }
    }

    return 0;
}


sub _addUser
{
   my ($self, $user, $password) = @_;

   unless ($self->{captiveportal}->configured()) {
       return;
   }

   #my $model = EBox::Model::ModelManager::instance()->model('zarafa/ZarafaUser');
   #$self->setHasAccount($user, $model->enabledValue());
   #$self->setHasContact($user, $model->contactValue());
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
