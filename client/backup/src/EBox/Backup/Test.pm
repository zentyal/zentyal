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
use EBox::Config::TestStub;
use EBox::Global::TestStub;
use File::Slurp qw(read_file write_file);
use EBox::FileSystem qw(makePrivateDir);

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
  makePrivateDir (EBox::Backup::dumpDir());
  makePrivateDir (EBox::Backup::restoreDir());

  system "rm -rf /tmp/backup";
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
}



sub backupAndRestoreTest : Test(6)
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
					  my ($self, $dir) = @_;
					  my $backedUpData =  read_file ("$dir/canary" );
					  $backup->setCanary($backedUpData);
					});
			    return $bh;
			  },


			  setCanary => sub { my ($self, $canary) = @_; $self->{canary} = $canary },
			  canary => sub { my ($self) = @_; return $self->{canary} },
			 ],
		);


  my $backup = EBox::Global->modInstance('backup');
  my $canaryJail = EBox::Global->modInstance('canaryJail');
  $canaryJail->setCanary('before');

  
  lives_ok { $backup->backup() } 'backup()';

  $canaryJail->setCanary('after');
  die 'canary not changed' if $canaryJail->canary() ne 'after';

  lives_ok { $backup->restore() } 'restore()';
  is $canaryJail->canary(), 'before', 'Checking if canaryJail module state was restored from backup';

  # we check if all the backupHelpers where correctly used
  my @backupHelpers = map { $_->can('backupHelper') ? $_->backupHelper() : ()  }  @{ EBox::Global->modInstances() };
  foreach my $mockBh (@backupHelpers) {
    is $mockBh->call_pos(1), 'dumpConf', 'Checking that dumpConf was called in the mocked backupHelper';
    is $mockBh->call_pos(2), 'restoreConf', 'Checking that restoreConf was called in the mocked backupHelper';
    is $mockBh->call_pos(3), undef, 'Checking that no more methods upon the backupHelper were called';
  }
}


1;
