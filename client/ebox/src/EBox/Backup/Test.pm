# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::Backup::Test;

use strict;
use warnings;

use base 'EBox::Test::Class';

use Test::MockObject;
use Test::More;
use Test::Exception;
use EBox::Test qw(checkModuleInstantiation fakeEBoxModule);
use EBox::Gettext;
use File::Slurp qw(read_file write_file);
use EBox::FileSystem qw(makePrivateDir);


use Readonly;
Readonly::Scalar my $GCONF_CANARY_KEY => '/ebox/modules/canaryGConf/canary';
Readonly::Scalar my $GCONF_EXTENDED_CANARY_KEY => '/ebox/modules/canaryExtended/key';
Readonly::Scalar my $CANARY_MODULE_VERSION => 'canary 0.1';

sub testDir
{
  return '/tmp/ebox.backup.test';
}


sub notice : Test(startup)
{
  diag 'This test use GConf and may left behind some test entries in the tree /ebox'; 
}


sub setupDirs : Test(setup)
{
  my ($self) = @_;

  return if !exists $INC{'EBox/Backup.pm'};

#  EBox::Config::TestStub::fake( tmp => $self->testDir() );
  EBox::Test::setEBoxConfigKeys(conf => testDir(), tmp => $self->testDir());

  my $testDir = $self->testDir();
  system "rm -rf $testDir";

  makePrivateDir($testDir);

  system "rm -rf /tmp/backup";
  ($? == 0) or die $!;
  makePrivateDir('/tmp/backup');
}



sub _useOkTest : Test(1)
{
  use_ok('EBox::Backup');
}




sub setUpCanaries : Test(setup)
{
  my ($self) = @_;


  fakeEBoxModule(
		 name => 'canaryExtended',
		 subs => [
			  setCanary => sub { my ($self, $canary) = @_; $self->{canary} = $canary },
			  canary => sub { my ($self) = @_; return $self->{canary} },
			  setVersion => sub { my ($self, $version) = @_; $self->{version} = $version },
			  version => sub { my ($self) = @_; return $self->{version} },
			  extendedBackup => sub {
			    my ($self, %params) = @_;
			    my $dir = $params{dir};
			    write_file ("$dir/canary", $self->{canary} );
			  },
			  extendedRestore => sub {
			    my ($self, %params) = @_;
			    my $dir = $params{dir};
			    my $versionInfo = $params{version};
			    my $backedUpData =  read_file ("$dir/canary" );
			    $self->setCanary($backedUpData);
			    $self->setVersion($versionInfo);
			  },
			 ],
		);
  fakeEBoxModule(
		 name => 'canaryGConf',
		);

}


sub setCanaries
{
  my ($value) = @_;

  setGConfCanary($value);

  my $client = Gnome2::GConf::Client->get_default;
  $client->set_string($GCONF_EXTENDED_CANARY_KEY, $value);
  die 'gconf extended canary not changed' if $client->get_string($GCONF_CANARY_KEY) ne $value;

  my $canaryExtended = EBox::Global->modInstance('canaryExtended');
  $canaryExtended->setCanary($value);
  $canaryExtended->setVersion($CANARY_MODULE_VERSION);
  die 'canary not changed' if $canaryExtended->canary() ne $value;
}


sub setGConfCanary
{
  my ($value) = @_;
  my $client = Gnome2::GConf::Client->get_default;
  $client->set_string($GCONF_CANARY_KEY, $value);
  die 'gconf canary not changed' if $client->get_string($GCONF_CANARY_KEY) ne $value;
}

sub checkCanaries
{
  my ($expectedValue, $fullRestore) = @_;  
  my $value;

  checkGConfCanary($expectedValue);

  my $client = Gnome2::GConf::Client->get_default;
  $value = $client->get_string($GCONF_EXTENDED_CANARY_KEY);
  is $value, $expectedValue, 'Checking GConf data of canary module with extended backup and restore';

  my $canaryExtended = EBox::Global->modInstance('canaryExtended');
  $value = $canaryExtended->canary();
  if ($fullRestore) {
    is $value, $expectedValue, 'Checking extra data of canary module with extended backup and restore';
  }
  else {
    isnt $value, $expectedValue, 'Checking extra data of canary module was not restored with configuration restore';
  }


  my $version  = $canaryExtended->version();
  is $version, $CANARY_MODULE_VERSION, 'Checking if version information was correctly backed';
}


sub checkGConfCanary
{
  my ($expectedValue) = @_;
  my $client = Gnome2::GConf::Client->get_default;
  my $value = $client->get_string($GCONF_CANARY_KEY);
  is $value, $expectedValue, 'Checking GConf data of simple module canary';
}

sub teardownGConfCanary : Test(teardown)
{
  my $client = Gnome2::GConf::Client->get_default;
  $client->unset($GCONF_CANARY_KEY);  
  $client->unset($GCONF_EXTENDED_CANARY_KEY);  
}

sub teardownCanaryModule : Test(teardown)
{
  my ($self) = @_;
  delete $self->{cachedBH}; #delete cached backupHelper

  EBox::Test::setConfig(); 
}

# that counts for 5 tests
sub checkStraightRestore
{
  my ($archiveFile, $options_r, $msg) = @_;

  my $backup = new EBox::Backup();
  setCanaries('afterBackup');
  lives_ok { $backup->restoreBackup($archiveFile, @{ $options_r  }) } $msg;

  my %options = @{ $options_r  };
  checkCanaries('beforeBackup', $options{fullRestore});
}


# that counts for 5 tests
sub checkDeviantRestore
{
  my ($archiveFile, $options_r, $msg) = @_;

  my $backup = new EBox::Backup();
  setCanaries('afterBackup');
  dies_ok { $backup->restoreBackup($archiveFile, @{ $options_r  }) } $msg;
  diag "Checking that failed restore has not changed the configuration";
  checkCanaries('afterBackup', 1);
}


sub invalidArchiveTest : Test(5)
{
  my ($self) = @_;
  my $incorrectFile = $self->testDir() . '/incorrect';
  system "cp $0 $incorrectFile";
  ($? == 0) or die "$!";
  checkDeviantRestore($incorrectFile, [], 'restoreBackup() called with a incorrect file');
}

sub restoreConfigurationBackupTest : Test(12)
{
  my ($self) = @_;

  my $backup = new EBox::Backup();
  my $configurationBackup;
  my $fullBackup;
 
  setCanaries('beforeBackup');
  lives_ok { $configurationBackup = $backup->makeBackup(description => 'test configuration backup') } 'make a configuration backup';
  checkStraightRestore($configurationBackup, [fullRestore => 0], 'configuration restore from a configuration backup');

  setCanaries('beforeBackup');
  lives_ok { $fullBackup = $backup->makeBackup(description => 'test full backup', fullBackup => 1) } 'make a full backup';
  checkStraightRestore($fullBackup, [fullRestore => 0], 'configuration restore from a full backup');
}

sub restoreFullBackupTest : Test(12)
{
  my ($self) = @_;

  my $backup = new EBox::Backup();
  my $configurationBackup;
  my $fullBackup;
 
  setCanaries('beforeBackup');
  lives_ok { $configurationBackup = $backup->makeBackup(description => 'test configuration backup', fullBackup => 0) } 'make a configuration backup';
  checkDeviantRestore($configurationBackup, [fullRestore => 1], 'checking that a full restore is forbidden from a configuration backup' );

  setCanaries('beforeBackup');
  lives_ok { $fullBackup = $backup->makeBackup(description => 'test full backup', fullBackup => 1) } 'make a full backup';
  checkStraightRestore($fullBackup, [fullRestore => 1], 'full restore from a full backup');
}


sub restoreWithModulesMismatchTest : Test(9)
{
  my ($self) = @_;

  my $backup = new EBox::Backup();
 
  setCanaries('beforeBackup');
  my $backupFile = $backup->makeBackup(description => 'test configuration backup', fullBackup => 0);

  # add one more module
  fakeEBoxModule( name => 'suprefluousModule', );
  
  checkDeviantRestore($backupFile, [fullRestore => 0], 'checking that a restore with a module mismatch (one more module) fails' );

  # with one less module
  EBox::Test::setConfig();
  fakeEBoxModule( name => 'canaryGConf', );
  setGConfCanary('afterBackup');
  dies_ok { $backup->restoreBackup($backupFile, fullRestore => 0) } 'checking that a restore with a module mismatch (one less module) fails';
  checkGConfCanary('afterBackup');

  # with same number but distinct modules
  EBox::Test::setConfig();
  fakeEBoxModule( name => 'canaryGConf', );
  fakeEBoxModule( name => 'suprefluousModule', );
  setGConfCanary('afterBackup');
  dies_ok { $backup->restoreBackup($backupFile, fullRestore => 0) } 'checking that a restore with a module mismatch (same nubmer but different modules) fails';
  checkGConfCanary('afterBackup');
}


sub listBackupsTest : Test(5)
{
  my ($self) = @_;
  diag "The backup's details of id a are not tested for now. The date detail it is only tested as relative order";

  my $backup = new EBox::Backup();
  my @backupParams = (
		      [description => 'configuration backup', fullBackup => 0], 
		      [description => 'full backup', fullBackup => 1],
		      );
 
  setCanaries('indiferent configuration');
  foreach (@backupParams) {
    $backup->makeBackup(@{ $_ });
    sleep 1;
  }

  my @backups = @{$backup->listBackups()};
  is @backups, @backupParams, 'Checking number of backups listed';

  foreach my $backup (@backups) {
    my %backupParam = @{ pop @backupParams };
    my $awaitedDescription = $backupParam{description};
    my $awaitedType        = $backupParam{fullBackup} ? 'full backup' : 'configuration backup';

    is $backup->{description}, $awaitedDescription, 'Checking backup description';
    is $backup->{type}, $awaitedType, 'Checking backup type';
  }

  
}


1;
