use strict;
use warnings;
use constant TESTS => 10;
use Test::More tests => TESTS;

use lib '..';

use EBox::Ldap;
use EBox::Sudo;
use EBox;

EBox::init();


my $ldap = EBox::Ldap->instance();


ok $ldap->ldapCon, 'test conexion before restarting ldap';

foreach (2 .. TESTS) {
$ldap->_pauseAndExecute(cmds => ["ls /"]);
ok $ldap->ldapCon, 'test conexion after calling _pauseAndExecute thus restarting ldap';
}

