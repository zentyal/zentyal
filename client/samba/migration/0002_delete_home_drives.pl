#!/usr/bin/perl

#  Migration between gconf data version X and Y
#
#       This migration script takes care of... TODO
#
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::MigrationBase';

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
#   Overrides <EBox::MigrationBase::runGConf>
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
