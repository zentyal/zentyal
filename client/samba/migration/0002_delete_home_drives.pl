#!/usr/bin/perl

# Copyright (C) 2008-2010 eBox Technologies S.L.
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

#  Migration between gconf data version X and Y
#
#       This migration script takes care of... TODO
#
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Config;
use EBox::Sudo;
use EBox::Ldap;

use Error qw(:try);

# Method: runGConf
#
#   Overrides <EBox::Migration::Base::runGConf>
#
sub runGConf
{
    my ($self) = @_;

    my $usersMod = EBox::Global->modInstance('users');
    my $ldap = EBox::Ldap->instance();

    my @users;
    # if LDAP is not yet initialized, users() will fail
    try {
        @users = $usersMod->users();
    } catch Error with {};
    foreach my $user (@users) {
        my $uid = $user->{username};
        my $dn = "uid=$uid," . $usersMod->usersDn;
        $ldap->delAttribute($dn, 'sambaHomeDrive');
    }
}

# Main

EBox::init();

my $module = EBox::Global->modInstance('samba');
my $migration = new EBox::Migration(
        'gconfmodule' => $module,
        'version' => 2,
        );
$migration->execute();

1;
