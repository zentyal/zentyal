use strict;
use warnings;

use Test::More tests => 10;
use Test::Exception;
use Error qw(:try);

use lib '../..';

use Readonly;
Readonly::Scalar my $TEST_DIR => '/tmp/ebox.usersandgroups.itest';
Readonly::Scalar my $BACKUP_DIR => "$TEST_DIR/backup";
Readonly::Scalar my $EXTENDED_BACKUP_DIR => "$TEST_DIR/extended";
Readonly::Scalar my $CANARY_USER  => 'canary';

system "rm -rf $TEST_DIR";


use EBox;
EBox::init();

foreach my $dir ($TEST_DIR, $BACKUP_DIR, $EXTENDED_BACKUP_DIR) {
  mkdir $dir or die "Can not create directory $dir"; 
}




use_ok('EBox::UsersAndGroups');

_cleanUsers();
try {
  _backupCanaryTest();
}
finally {
  _cleanUsers();
};


sub _backupCanaryTest
{
  my $usersAndGroups = EBox::Global->modInstance('users');

  lives_ok { $usersAndGroups->makeBackup($BACKUP_DIR, fullBackup => 0)  }  "Configuration backup tried in $BACKUP_DIR";
  checkLdap($usersAndGroups);

  lives_ok { $usersAndGroups->makeBackup($EXTENDED_BACKUP_DIR, fullBackup => 1)  }  "Configuration backup tried in $EXTENDED_BACKUP_DIR";
  checkLdap($usersAndGroups);


  $usersAndGroups->addUser ({user => $CANARY_USER, fullname => 'ea', password => 'ea', comment => 'ea'}, 0);

  ok $usersAndGroups->userExists($CANARY_USER), 'Checking that canry was added';


  lives_ok { $usersAndGroups->restoreBackup($BACKUP_DIR, fullBackup => 0)  }  "Configuration restore";
  ok !$usersAndGroups->userExists($CANARY_USER), 'Checking that canary is not here';
}

sub checkLdap
{
  my ($usersAndGroups) = @_;

  system 'pgrep slapd';
  ok ($? == 0), 'Checking that slapd is active';

  lives_ok { $usersAndGroups->users() } 'Checking tha we can get user list from ldap via users and groups';
}


sub _cleanUsers
{
  my $usersAndGroups = EBox::Global->modInstance('users');
  if ($usersAndGroups->userExists($CANARY_USER)) {
    $usersAndGroups->delUser($CANARY_USER);
  }
}

1;
