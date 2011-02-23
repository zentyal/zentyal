#!/usr/bin/perl
#
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

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Config;
use EBox::Sudo;
use EBox::SambaLdapUser;

sub runGConf
{
    my ($self) = @_;

    my $samba = $self->{gconfmodule};
    if (not $samba->configured()) {
        return;
    }

    $self->_updateSchemas();
    $self->_updateData();
}

sub _updateSchemas
{
    my ($self) = @_;

    # FIXME It only supports standalone LDAP
    my $ldapCat = q{slapcat -bcn=config };
    my @output = EBox::Sudo::root($ldapCat);
    foreach my $line (@output) {
        if ($line =~ m{cn=\{\d+\}quota,cn=schema,cn=config}) {
            # quota schema is present, nothing to do
            return;
        }
    }

    my $samba = $self->{gconfmodule};
    # is assumed that performLDAP actions is idempotent!
    $samba->performLDAPActions();
}

sub _updateData
{
    my ($self) = @_;
    my $users = EBox::Global->modInstance('users');
    my $smbldap = new EBox::SambaLdapUser;

    foreach my $user ($users->users()) {
        my $username = $user->{username};
        my $quota = $smbldap->currentUserQuota($username);
        if ($quota >= 0) {
            $smbldap->setUserQuota($username, $quota);
        }
    }
}

EBox::init();

my $sambaMod = EBox::Global->modInstance('samba');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $sambaMod,
        'version' => 3,
        );
$migration->execute();
