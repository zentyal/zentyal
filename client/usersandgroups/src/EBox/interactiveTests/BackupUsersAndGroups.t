use strict;
use warnings;

use Test::More tests => 10;
use Test::Exception;

use lib '../..';

use Readonly;
Readonly::Scalar my $TEST_DIR => '/tmp/ebox.usersandgroups.itest';
Readonly::Scalar my $BACKUP_DIR => "$TEST_DIR/backup";
Readonly::Scalar my $EXTENDED_BACKUP_DIR => "$TEST_DIR/extended";

system "rm -rf $TEST_DIR";

foreach my $dir ($TEST_DIR, $BACKUP_DIR, $EXTENDED_BACKUP_DIR) {
  mkdir $dir or die "Can not create directory $dir"; 
}




use_ok('EBox::UsersAndGroups');

my $usersAndGroups = EBox::Global->modInstance('users');

lives_ok { $usersAndGroups->makeBackup($BACKUP_DIR, fullBackup => 0)  }  "Configuration backup tried in $BACKUP_DIR";
checkLdap($usersAndGroups);

lives_ok { $usersAndGroups->makeBackup($EXTENDED_BACKUP_DIR, fullBackup => 1)  }  "Configuration backup tried in $EXTENDED_BACKUP_DIR";
checkLdap($usersAndGroups);


$usersAndGroups->addUser ({user => 'canary', fullname => 'ea', password => 'ea', comment => 'ea'}, 0);

ok $usersAndGroups->userExists('canary'), 'Checking that canry was added';


lives_ok { $usersAndGroups->restoreBackup($BACKUP_DIR, fullBackup => 0)  }  "Configuration restore";
ok !$usersAndGroups->userExists('canary'), 'Checking that canary is not here';


sub checkLdap
{
  my ($usersAndGroups) = @_;

  system 'pgrep slapd';
  ok ($? == 0), 'Checking that slapd is active';

  lives_ok { $usersAndGroups->users() } 'Checking tha we can get user list from ldap via users and groups';
}

1;
