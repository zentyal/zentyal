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
Readonly::Scalar my $GCONF_CANARY_KEY => '/ebox/canary';
Readonly::Scalar my $CANARY_MODULE_VERSION => 'canary 0.1';

sub testDir
{
  return '/tmp/ebox.backup.test';
}




sub setupDirs : Test(setup)
{
  my ($self) = @_;

  return if !exists $INC{'EBox/Backup.pm'};

  EBox::Config::TestStub::fake( tmp => $self->testDir() );

  my $testDir = $self->testDir();
  system "rm -rf $testDir";

  makePrivateDir($testDir);

  system "rm -rf /tmp/backup";
  ($? == 0) or die $!;
  makePrivateDir('/tmp/backup');
}

sub setupEBoxModules : Test(setup)
{
  EBox::Global::TestStub::setEBoxModule('backup' => 'EBox::Backup');
}

sub _moduleInstantiationTest : Test(1)
{
  my ($self) = @_;

  EBox::Config::TestStub::setConfigKeys( tmp => $self->testDir() );
  checkModuleInstantiation('backup', 'EBox::Backup');
  fakeBackupAndRestoreFileSubs();
}



sub fakeBackupAndRestoreFileSubs 
{
  Test::MockObject->fake_module('EBox::Backup',
			       backupFiles => sub {
				 my ($self) = @_;
				 my $dir = $self->dumpDir();
				 system "rm -rf /tmp/backup/*";
				 system "cp -r $dir/* /tmp/backup/";
			       },
			       restoreFiles => sub {
				 my ($self) = @_;
				 my $dir = $self->dumpDir();
				 system "cp -r  /tmp/backup/* $dir";
			       }
			       );

}


sub setUpCanaryModule
{
  my ($self) = @_;


  fakeEBoxModule(
		 name => 'canaryJail',
		 subs => [
			  backupHelper => sub {
			    my ($backup, $dir) = @_;
			    my $bh;
			    # we must cache the mocked backupHelper  to be able to test it after the backup process
			    if (!exists $self->{cachedBH}) {
			       $self->{cachedBH} = new Test::MockObject;
			    }
			    $bh =  $self->{cachedBH};

			    $bh->mock ( dumpConf => sub {
					  my ($self, $dir) = @_;
					  write_file ("$dir/canary", $backup->{canary} );
					});
			    $bh->mock ( restoreConf => sub {
					  my ($self, $dir, $versionInfo) = @_;
					  my $backedUpData =  read_file ("$dir/canary" );
					  $backup->setCanary($backedUpData);
					  $backup->setVersion($versionInfo);
					});
			    $bh->mock (  version => sub {
					   return $CANARY_MODULE_VERSION;
					});
			    return $bh;
			  },


			  setCanary => sub { my ($self, $canary) = @_; $self->{canary} = $canary },
			  canary => sub { my ($self) = @_; return $self->{canary} },
			  setVersion => sub { my ($self, $version) = @_; $self->{version} = $version },
			  version => sub { my ($self) = @_; return $self->{version} },

			 ],
		);

}


sub setCanaries
{
  my ($value) = @_;

  my $client = Gnome2::GConf::Client->get_default;
  $client->set_string($GCONF_CANARY_KEY, $value);
  die 'gconf canart not changed' if $client->get_string($GCONF_CANARY_KEY) ne $value;

  my $canaryJail = EBox::Global->modInstance('canaryJail');
  $canaryJail->setCanary($value);
  die 'canary not changed' if $canaryJail->canary() ne $value;
}


sub checkCanaries
{
  my ($expectedValue) = @_;  
  my $value;

  my $client = Gnome2::GConf::Client->get_default;
  $value = $client->get_string($GCONF_CANARY_KEY);
  is $value, $expectedValue, 'Checking GConf canary';

  my $canaryJail = EBox::Global->modInstance('canaryJail');
  $value = $canaryJail->canary();
  is $value, $expectedValue, 'Checking module canary';

  my $version  = $canaryJail->version();
  is $version, $CANARY_MODULE_VERSION, 'Checking if version information was correctly backed';
}


sub checkBackupHelpers
{
  # we check if all the backupHelpers where correctly used
  my @backupHelpers = map { $_->can('backupHelper') ? $_->backupHelper() : ()  }  @{ EBox::Global->modInstances() };
  foreach my $mockBh (@backupHelpers) {
    is $mockBh->call_pos(1), 'version', 'Checking that version was called in the mocked backupHelper';
    is $mockBh->call_pos(2), 'dumpConf', 'Checking that dumpConf was called in the mocked backupHelper';
    is $mockBh->call_pos(3), 'restoreConf', 'Checking that restoreConf was called in the mocked backupHelper';
    is $mockBh->call_pos(4), undef, 'Checking that no more methods upon the backupHelper were called';
  }
}

sub teardownGConfCanary : Test(teardown)
{
  my $client = Gnome2::GConf::Client->get_default;
  $client->unset($GCONF_CANARY_KEY);  
}

sub teardownCanaryModule : Test(teardown)
{
  my ($self) = @_;
  delete $self->{cachedBH}; #delete cached backupHelper

  EBox::GConfModule::TestStub::setConfig(); 
  EBox::Global::TestStub::setEBoxModule('backup' => 'EBox::Backup');
}


sub backupAndRestoreTest : Test(9)
{
  my ($self) = @_;
  fakeBackupAndRestoreFileSubs();
  $self->setUpCanaryModule();

  my $backup = EBox::Global->modInstance('backup');
 
 
  setCanaries('beforeBackup');
  lives_ok { $backup->backup() } 'backup()';

  setCanaries('afterBackup');
  lives_ok { $backup->restore() } 'restore()';

  checkCanaries('beforeBackup');
  
  checkBackupHelpers();
}


sub gconfDumpAndRestoreTest : Test(3)
{
  my $backup = EBox::Backup->_create();

  EBox::FileSystem::makePrivateDir($backup->dumpDir());

  my $beforeValue = 'beforeDump';
  my $client = Gnome2::GConf::Client->get_default;
  $client->set_string($GCONF_CANARY_KEY, $beforeValue);

  lives_ok { $backup->dumpGConf() } "Dumping GConf";

  $client->set_string($GCONF_CANARY_KEY, 'After dump');

  # do nothing and suppose that a backup has been done...

  lives_ok { $backup->restoreGConf() } 'Restoring GConf';
  is $client->get_string($GCONF_CANARY_KEY), $beforeValue, 'Checking canary GConf entry after restore';


}

1;
