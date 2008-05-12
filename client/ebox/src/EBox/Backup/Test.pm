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

use lib '../..';

use base 'EBox::Test::Class';

use EBox::Backup;

use Test::MockObject;
use Test::More;
use Test::Exception;
use Test::Differences;
use Test::File;

use EBox::Test qw(checkModuleInstantiation);
use EBox::TestStubs qw(fakeEBoxModule);
use EBox::Gettext;
use File::Slurp qw(read_file write_file);
use EBox::FileSystem qw(makePrivateDir);
use Perl6::Junction qw(all);



use Readonly;
Readonly::Scalar my $GCONF_CANARY_KEY => '/ebox/modules/gConfCanary/canary';
Readonly::Scalar my $GCONF_EXTENDED_CANARY_KEY => '/ebox/modules/extendedCanary/key';
Readonly::Scalar my $GCONF_MIXEDCONF_CANARY_KEY => '/ebox/modules/mixedConfCanary/key';



use constant BEFORE_BACKUP_VALUE => 'beforeBackup';
use constant AFTER_BACKUP_VALUE  => 'afterBackup';
use constant BUG_BACKUP_VALUE  => 'bug';

sub testDir
{
  return '/tmp/ebox.backup.test';
}



sub notice : Test(startup)
{
  diag 'This test use GConf and may left behind some test entries in the tree /ebox';
  diag 'Remember you need the special GConf packages from eBox repository. Otherwise these tests will fail in awkward ways';
}



# needed for progress indicator stuff
sub setupProgressIndicatorHostModule : Test(setup)
{
  
   fakeEBoxModule(name => 'apache');
}


sub setupDirs : Test(setup)
{
  my ($self) = @_;

  return if !exists $INC{'EBox/Backup.pm'};

  EBox::TestStubs::setEBoxConfigKeys(conf => testDir(), tmp => $self->testDir());

  my $testDir = $self->testDir();
  system "rm -rf $testDir";

  makePrivateDir($testDir);

  system "rm -rf /tmp/backup";
  ($? == 0) or die $!;
  makePrivateDir('/tmp/backup');
}

sub setUpCanaries : Test(setup)
{
  my ($self) = @_;

  setupGConfCanary();
  setupExtendedCanary();
  setupMixedConfCanary();


}


sub setupGConfCanary
{
  fakeEBoxModule(
		 name => 'gConfCanary',
		 subs => [
			  revokeConfig => sub {
			    _canaryRevokeGConf($GCONF_CANARY_KEY);
			  }
			 ]
		);

}

sub setupExtendedCanary
{
  fakeEBoxModule(
		 name => 'extendedCanary',
		 subs => [
			  setCanary => sub { my ($self, $canary) = @_; $self->{canary} = $canary },
			  canary => sub { my ($self) = @_; return $self->{canary} },
		
			  extendedBackup => sub {
			    my ($self, %params) = @_;
			    my $dir = $params{dir};
			    write_file ("$dir/canary", $self->{canary} );
			  },
			  extendedRestore => sub {
			    my ($self, %params) = @_;
			    my $dir = $params{dir};
			    my $backedUpData =  read_file ("$dir/canary" );
			    $self->setCanary($backedUpData);
			  },
			  revokeConfig => sub {
			    _canaryRevokeGConf($GCONF_EXTENDED_CANARY_KEY);
			  }
			 ],
		);

}


# this canary contains sensitive data so in debug
sub setupMixedConfCanary
{


 fakeEBoxModule(
		 name => 'mixedConfCanary',
		 subs => [
			  setCanary => sub { my ($self, $canary) = @_; $self->{canary} = $canary },
			  canary => sub { my ($self) = @_; return $self->{canary} },
			  dumpConfig => sub {
			    my ($self, $dir, %options) = @_;
			    EBox::GConfModule::_dump_to_file($self, $dir);
			    if ($options{bug}) {
			      write_file ("$dir/canary", BUG_BACKUP_VALUE );
			    }
			    else {
			      write_file ("$dir/canary", $self->{canary} );			      
			    }

			  },
			  restoreConfig => sub {
			    my ($self, $dir) = @_;
			    EBox::GConfModule::_load_from_file($self, $dir);
			    my $backedUpData =  read_file ("$dir/canary" );
			    $self->setCanary($backedUpData);
			  },
			  revokeConfig => sub {
			    _canaryRevokeGConf($GCONF_MIXEDCONF_CANARY_KEY);
			  }
			 ],
		);

}
 

sub setCanaries
{
  my ($value) = @_;

  setGConfCanary($value);
  setExtendedCanary($value);
  setMixedConfCanary($value);
}


sub setGConfCanary
{
  my ($value) = @_;
  _setGConfString($GCONF_CANARY_KEY, $value);

  my $canaryConf = EBox::Global->modInstance('gConfCanary');
  $canaryConf->setAsChanged();
}

sub setExtendedCanary
{
  my ($value) = @_;

  _setGConfString($GCONF_EXTENDED_CANARY_KEY, $value);

  my $extendedCanary = EBox::Global->modInstance('extendedCanary');
  $extendedCanary->setCanary($value);
  $extendedCanary->setAsChanged();

  die 'canary not changed' if $extendedCanary->canary() ne $value;
}
 

sub setMixedConfCanary
{
  my ($value) = @_;

  _setGConfString($GCONF_MIXEDCONF_CANARY_KEY, $value);


  my $mixedConfCanary = EBox::Global->modInstance('mixedConfCanary');
  $mixedConfCanary->setCanary($value);
  $mixedConfCanary->setAsChanged();

  die 'canary not changed' if $mixedConfCanary->canary() ne $value;
}


sub _canaryRevokeGConf
 {
   my ($key) = @_;
   _setGConfString($key, AFTER_BACKUP_VALUE);
}


sub _setGConfString
{
  my ($key, $value) = @_;
  defined $key or die "Not key supplied";
  defined $value or die "Not value supplied for key $key";

  my $client = Gnome2::GConf::Client->get_default;
  defined $client or die "Can not retrieve GConf client";

  $client->set_string($key, $value);

  die "gconf key $key not changed" if $client->get_string($key) ne $value;
}


sub checkCanaries
{
  my ($expectedValue, $fullRestore) = @_;  

  checkGConfCanary($expectedValue);
  checkExtendedCanary($expectedValue, $fullRestore);
  checkMixedConfCanary($expectedValue);
}



sub checkCanariesOnlyGConf
{
  my ($expectedValue) = @_;

  checkGConfCanaryGconf($expectedValue);
  checkExtendedCanaryGConf($expectedValue);
  checkMixedConfCanaryGconf($expectedValue);
}

sub checkGConfCanary
{
  my ($expectedValue) = @_;

  checkGConfCanaryGconf($expectedValue);
}

sub checkGConfCanaryGconf
{
  my ($expectedValue) = @_;

  my $client = Gnome2::GConf::Client->get_default;
  my $value = $client->get_string($GCONF_CANARY_KEY);
  is $value, $expectedValue, 'Checking GConf data of simple module canary';
}


sub checkExtendedCanaryGConf
{
  my ($expectedValue) = @_;

  my $client = Gnome2::GConf::Client->get_default;
  my $value;

  $value = $client->get_string($GCONF_EXTENDED_CANARY_KEY);
  is $value, $expectedValue, 'Checking GConf data of canary module with extended backup and restore';
}

sub checkExtendedCanary
{
  my ($expectedValue, $fullRestore) = @_;
  
  checkExtendedCanaryGConf($expectedValue);
  checkExtendedCanaryData($expectedValue, $fullRestore);


}


sub checkExtendedCanaryData
{
  my ($expectedValue, $dataRestored) = @_;
  
  my $value;
  my $extendedCanary = EBox::Global->modInstance('extendedCanary');
  $value = $extendedCanary->canary();
  if ($dataRestored ) {
    is $value, $expectedValue, 'Checking extra data of canary module with extended backup and restore';
  }
  else {
    isnt $value, $expectedValue, 'Checking extra data of canary module was not restored with configuration restore';
  }
}



sub checkMixedConfCanaryGconf
{
  my ($expectedValue) = @_;

  my $client = Gnome2::GConf::Client->get_default;
  my $value;

  $value = $client->get_string($GCONF_MIXEDCONF_CANARY_KEY);
  is $value, $expectedValue, 'Checking GConf configuration data of canary module with mixed config';
}


sub checkMixedConfCanaryOtherConf
{
  my ($expectedValue) = @_;

  my $mixedConfCanary = EBox::Global->modInstance('mixedConfCanary');
  my $value = $mixedConfCanary->canary();
  is $value, $expectedValue, 'Checking no-GConf configuration  data of canary module';
}

sub checkMixedConfCanary
{
  my ($expectedValue) = @_;

  checkMixedConfCanaryGconf($expectedValue);
  checkMixedConfCanaryOtherConf($expectedValue);
}




sub teardownGConfCanary : Test(teardown)
{
  my $client = Gnome2::GConf::Client->get_default;
  $client->unset($GCONF_CANARY_KEY);  
  $client->unset($GCONF_EXTENDED_CANARY_KEY);  
  $client->unset($GCONF_MIXEDCONF_CANARY_KEY);  
}

sub teardownCanaryModule : Test(teardown)
{
  my ($self) = @_;
  EBox::TestStubs::setConfig(); 
}

# this counts for 7 tests
sub checkStraightRestore
{
  my ($archiveFile, $options_r, $msg) = @_;

  my $backup = new EBox::Backup();
  setCanaries(AFTER_BACKUP_VALUE);
  lives_ok { $backup->restoreBackup($archiveFile, @{ $options_r  }) } $msg;

  my %options = @{ $options_r  };
  checkCanaries(BEFORE_BACKUP_VALUE, $options{fullRestore});

  checkModulesChanged(
	name => 'Checking wether all restored modules have the changed state set' 
		     );
}


sub checkModulesChanged
{
  my %params = @_;
  my $name  = $params{name};

  my $global = EBox::Global->getInstance();

  my @modules;
  if (exists $params{modules}) {
    @modules = @{ $params{modules} };
  }
  else {
    @modules = @{ $global->modNames() };
  }

  my @modulesChanged =  grep {  $global->modIsChanged($_) } @modules;

  diag "moduled changed @modulesChanged";
  diag "modules @modules";

#  is_deeply [sort @modulesChanged], [sort @modules], $name;
  use Test::Differences;
  eq_or_diff [sort @modulesChanged], [sort @modules], $name;
}


# this counts for 7 tests
sub checkDeviantRestore
{
  my ($archiveFile, $options_r, $msg) = @_;

  my $backup = new EBox::Backup();
  setCanaries(AFTER_BACKUP_VALUE);
  dies_ok { $backup->restoreBackup($archiveFile, @{ $options_r  }) } $msg;

  diag "Checking that failed restore has not changed the configuration";
  checkCanaries(AFTER_BACKUP_VALUE, 1);
}


sub checkMakeBackup
{
  my @backupParams = @_;

  my $global = EBox::Global->getInstance();
  $global->saveAllModules();

  my $backupArchive;
  my $b = new EBox::Backup;
  lives_ok { $backupArchive = $b->makeBackup(@backupParams)  } 'Checking wether backup is correctly done';
  
  return $backupArchive;
}


# this requires a correct testdata dir
sub invalidArchiveTest : Test(30)
{
  my ($self) = @_;
  my $incorrectFile = $self->testDir() . '/incorrect';
  system "cp $0 $incorrectFile";
  ($? == 0) or die "$!";
  checkDeviantRestore($incorrectFile, [], 'restoreBackup() called with a incorrect file');

  my @deviantFiles = (
		      ['badchecksum.tar', 'restoreBackup() called with a archive with fails checksum'],
		      ['badsize.tar', 'restoreBackup() called with a archive with uncompressed size exceeds available storage'],
		      ['missingtype.tar', 'restoreBackup() called with a archive missing type of backup information'],
		      ['badtype.tar', 'restoreBackup() called with a archive wuth incorrect backup type information'],
		     );

  foreach my $case (@deviantFiles) {
    my ($file, $msg) = @{ $case };
    $file = _testdataDir() . "/$file";
    (-f $file) or die "Unavailble test data file $file";

    checkDeviantRestore($file, [], $msg);
  }
}

sub _testdataDir 
{
  my $dir = __FILE__;
  $dir =~ s/Test\.pm/testdata/;

  return $dir;
}

sub restoreConfigurationBackupTest : Test(16)
{
  my ($self) = @_;
 
  my $configurationBackup;
  setCanaries(BEFORE_BACKUP_VALUE);
  $configurationBackup = checkMakeBackup(description => 'test configuration backup');
  checkStraightRestore($configurationBackup, [fullRestore => 0], 'configuration restore from a configuration backup');

  my $fullBackup;
  setCanaries(BEFORE_BACKUP_VALUE);
  $fullBackup = checkMakeBackup(description => 'test full backup', fullBackup => 1);
  checkStraightRestore($fullBackup, [fullRestore => 0], 'configuration restore from a full backup');
}


sub restoreBugreportTest : Test(14)
{
  my ($self) = @_;

  my $backup = new EBox::Backup();
  my $bugReportBackup;
 
  setCanaries(BEFORE_BACKUP_VALUE);
  lives_ok { $bugReportBackup = $backup->makeBugReport() } 'make a bug report';

  setCanaries(AFTER_BACKUP_VALUE);

  lives_ok { $backup->restoreBackup($bugReportBackup) } 'Restoring bug report';



  checkGConfCanary(BEFORE_BACKUP_VALUE);
  checkExtendedCanary(BEFORE_BACKUP_VALUE, 0 );

  # mixedConfCanary contains sensitive data in his non-gconf configuration
  checkMixedConfCanaryGconf(BEFORE_BACKUP_VALUE);
  checkMixedConfCanaryOtherConf(BUG_BACKUP_VALUE);

  checkDeviantRestore($bugReportBackup, [fullRestore => 1], 'full restore not allowed from a bug report');
}




sub restoreFullBackupTest : Test(15)
{
  my ($self) = @_;

  my $configurationBackup;
  setCanaries(BEFORE_BACKUP_VALUE);
  $configurationBackup = checkMakeBackup(description => 'test configuration backup', fullBackup => 0);
  checkDeviantRestore($configurationBackup, [fullRestore => 1], 'checking that a full restore is forbidden from a configuration backup' );

  my $fullBackup;
  setCanaries(BEFORE_BACKUP_VALUE);
  $fullBackup = checkMakeBackup(description => 'test full backup', fullBackup => 1);
  checkStraightRestore($fullBackup, [fullRestore => 1], 'full restore from a full backup');
}


sub partialRestoreTest : Test(15)
{
  my ($self) = @_;

  my $configurationBackup;
  setCanaries(BEFORE_BACKUP_VALUE);
  $configurationBackup = checkMakeBackup(description => 'test configuration backup', fullBackup => 0);

  setCanaries(AFTER_BACKUP_VALUE);

  # bad case: not modules to restore
  dies_ok {
    EBox::Backup->restoreBackup($configurationBackup, modsToRestore => []);
  } 'called restoreBackup with a empty list of modules to restore';

  # bad case: inexistent module
  dies_ok {
    EBox::Backup->restoreBackup(
				$configurationBackup, 
				modsToRestore => ['gConfCanary', 'inexistent'],
			       );
  } 'called restoreBackup with a list of modules t orestore which contains inexistent modules';

  # good cases

  my @cases = (
	       [qw(gConfCanary)],
	       [qw(gConfCanary extendedCanary)],
               [qw(gConfCanary extendedCanary mixedConfCanary)],
	      );

  foreach my $case (@cases) {
    my @modsToRestore = @{ $case };
    lives_ok {
      EBox::Backup->restoreBackup(
				  $configurationBackup,
				  modsToRestore => \@modsToRestore,
				 )
    } "Partial restore with modules @modsToRestore";

    my @checkSubs = map {
      'check' . ucfirst $_
    } @modsToRestore;

    foreach my $subName (@checkSubs) {
      my $sub = __PACKAGE__->can($subName);
      $sub->(BEFORE_BACKUP_VALUE, 0);
    }
  }

}

# XXX this must be remade taking in account that only modules both in the backup
# and in the global module list will be restored

# sub restoreWithModulesMissmatchTest : Test(46) { my ($self) = @_;
 
#   setCanaries(BEFORE_BACKUP_VALUE);
#   my $global       = EBox::Global->getInstance();
#   my @modsInBackup = @{ $global->modNames() };
  
#   my $backupFile = checkMakeBackup( fullBackup => 0 );  
  
#   my @straightCases;

#   # one more module
#   push @straightCases, sub {
#     fakeEBoxModule( name => 'superfluousModule', );
#   };

#   # additional module with met dependencies
#   push @straightCases, sub {
#     fakeEBoxModule( name => 'superfluousModule', 
# 		    subs => [
# 			     restoreDependencies => sub { return ['gConfCanary'] },
# 			    ],
# 		  );
#   };

#   # two additional modules with met dependencies between them
#   push @straightCases, sub {
#     fakeEBoxModule( name => 'superfluousModule1', );
#     fakeEBoxModule( name => 'superfluousModule2', 
# 		    subs => [
# 			     restoreDependencies => sub { return ['superfluousModule1'] },
# 			    ],
# 		  );
#   };


#   my @deviantCases;

#   # with a additional module with unmet dependencies
#   push @deviantCases, sub {
#     fakeEBoxModule( name => 'unmetDepModule', 
# 		    subs => [
# 			     restoreDependencies => sub { return ['inexistentModule'] },
# 			    ],
# 		  );
#   };
#   # with a recursive dependency
#   push @deviantCases, sub {
#     fakeEBoxModule( name => 'recursiveDepModule1', 
# 		    subs => [
# 			     restoreDependencies => sub { return ['recursiveDepModule2'] },
# 			    ],
# 		  );
#     fakeEBoxModule( name => 'recursiveDepModule2', 
# 		    subs => [
# 			     restoreDependencies => sub { return ['recursiveDepModule1'] },
# 			    ],
# 		  );
#   };
#   # with a module which depends on itself
#   push @deviantCases, sub {
#     fakeEBoxModule( name => 'depOnItselfModule', 
# 		    subs => [
# 			     restoreDependencies => sub { return ['depOnItselfModule'] },
# 			    ],
# 		  );
#   };
  

#   my $backup = new EBox::Backup();
#   foreach my $case (@straightCases) {
#     setUpCanaries();
#     setGConfCanary(AFTER_BACKUP_VALUE);
#     setMixedConfCanary(AFTER_BACKUP_VALUE);

#     $case->();
#     $self->_mangleModuleListInBackup($backupFile);

#     # restore backup
#     setCanaries(AFTER_BACKUP_VALUE);



#     lives_ok { 
#       $backup->restoreBackup($backupFile, fullRestore => 0) 
#     } 'checking restore without dependencies problems'   ;
    
#     # check after backup state
#     checkCanaries(BEFORE_BACKUP_VALUE, 0);
#     checkModulesChanged(
# 			name => 'Checking wether restored modules are marked as changed',
# 			modules => \@modsInBackup,
# 		       );
    
  
#     teardownCanaryModule();
#     teardownGConfCanary();
#   }


#   foreach my $case (@deviantCases) {
#     setUpCanaries();
#     setGConfCanary(AFTER_BACKUP_VALUE);
#     setMixedConfCanary(AFTER_BACKUP_VALUE);


#     $case->();
#     $self->_mangleModuleListInBackup($backupFile);

#     checkDeviantRestore($backupFile, [ fullRestore => 0], , 'checking wether restore with unmet dependencies raises error');

#     teardownGConfCanary();
#   }
  

# }

# this must be synchronized with EBox::Backup::_createM
sub _mangleModuleListInBackup
{
  my ($self, $archive) = @_;

  my $dir = $self->testDir();
  my $backupDir = "$dir/eboxbackup";
  mkdir $backupDir or die "cannot create $backupDir: $!";

  EBox::Backup->_createModulesListFile($backupDir);

  my $modlistFile = "eboxbackup/modules";

  my $replaceCmd = "tar -u  -C $dir -f $archive  $modlistFile";
  system $replaceCmd;

  system "rm -rf $backupDir";
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
    my $global = EBox::Global->getInstance();
    $global->saveAllModules();

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





sub backupDetailsFromArchiveTest : Test(9)
{
  setCanaries(BEFORE_BACKUP_VALUE);
  my $global = EBox::Global->getInstance();
  $global->saveAllModules();

  
  my $configurationBackupDescription = 'test configuration backup for detail test';
  my $configurationBackup = EBox::Backup->makeBackup(description => $configurationBackupDescription, fullBackup => 0) ;

  my $fullBackupDescription = 'test full backup for detail test';
  my $fullBackup = EBox::Backup->makeBackup(description => $fullBackupDescription, fullBackup => 1);

  my $bugreportBackupDescription = 'Bug report'; # string foun in EBox::Backup::makeBugReport
  my $bugreportBackup = EBox::Backup->makeBugReport();

  # XXX date detail IS NOT checked
  my %detailsExpectedByFile = (
			 $configurationBackup => {
						  description => $configurationBackupDescription,
						  type        => $EBox::Backup::CONFIGURATION_BACKUP_ID,
						 },
			 $fullBackup => {
						  description => $fullBackupDescription,
						  type        => $EBox::Backup::FULL_BACKUP_ID,
						 },
			 $bugreportBackup => {
						  description => $bugreportBackupDescription,
						  type        => $EBox::Backup::BUGREPORT_BACKUP_ID,
						 },
			);

  foreach my $file (keys %detailsExpectedByFile) {
    my $details_r;
    lives_ok { $details_r = EBox::Backup->backupDetailsFromArchive($file)  } 'Getting details from file';
    
    my $detailsExpected_r = $detailsExpectedByFile{$file};
    while (my ($detail, $value) = each %{ $detailsExpected_r }) {
      is $details_r->{$detail}, $value, "Checking value of backup detail $detail";
    }
  }
}



sub backupForbiddenWithChangesTest : Test(7)
{
  my ($self) = @_;

  setCanaries(BEFORE_BACKUP_VALUE);
  
  setCanaries(AFTER_BACKUP_VALUE);

  my $global = EBox::Global->getInstance();
  my @changedModules = grep {
    $global->modIsChanged($_);
  } @{ $global->modNames };


  throws_ok {
    my $b = new EBox::Backup;
    $b->makeBackup(description => 'test');
  }  qr/not saved changes/, 'Checkign wether the backup is forbidden with changed modules';


  checkCanaries(AFTER_BACKUP_VALUE, 1);

  

  checkModulesChanged(
		      name => 'Check wether module changed state has not be changed',
		      modules => \@changedModules,
		     );
}


sub restoreFailedTest : Test(6)
{
  my ($self) = @_;

  # we force failure in one of the modules
  my $forcedFailureMsg  = 'forced failure ';
  fakeEBoxModule(
		 name => 'unrestorableModule',
		 subs => [
			  restoreConfig => sub {
			    die $forcedFailureMsg;
			  },
			  revokeConfig => sub { },
			 ],
		);

  my $global = EBox::Global->getInstance();


  setCanaries(BEFORE_BACKUP_VALUE);
  my $backupArchive = checkMakeBackup();

  setCanaries(AFTER_BACKUP_VALUE);

  $global->saveAllModules();
  foreach my $mod (@{ $global->modInstances }) {
    $mod->setAsChanged();   # we mark modules as changed to be able to detect
                            # revoked modules
  }

  throws_ok {   
    my $b = new EBox::Backup;
    $b->restoreBackup($backupArchive);

  } qr /$forcedFailureMsg/, 
    'Checking wether restore failed as expected';

  diag "Checking modules for revoked values. We check only GConf values because currently the revokation only takes care of them";
  checkCanariesOnlyGConf(AFTER_BACKUP_VALUE);


  my @modules =  @{ $global->modNames() };
  my @modulesNotChanged =  grep {  (not $global->modIsChanged($_)) } @modules;

  ok scalar @modulesNotChanged > 0, 'Checking wether after the restore failure' . 
  ' some  modules not longer a changed state (this is a clue of revokation)' ;

  setupMixedConfCanary();
}



sub dataRestoreTest : Test(7)
{
  my ($self) = @_;

  setCanaries(BEFORE_BACKUP_VALUE);
  my $fullBackup = checkMakeBackup(fullBackup => 1);

  setCanaries(AFTER_BACKUP_VALUE);

  lives_ok {
    EBox::Backup->restoreBackup($fullBackup, dataRestore => 1)
  } 'trying a data restore';



  # gconf canary shouldn't be restored
  checkGConfCanary(AFTER_BACKUP_VALUE);
  # mixed conf canary shouldn't changed
  checkMixedConfCanary(AFTER_BACKUP_VALUE);
  
  # extended canary configuration should not be changed ..
  checkExtendedCanaryGConf(AFTER_BACKUP_VALUE);
  # .. but data must be restored
  checkExtendedCanaryData(BEFORE_BACKUP_VALUE, 1);
}


sub checkArchivePermissions : Test(3)
{
  my ($self) = @_;

  setCanaries(BEFORE_BACKUP_VALUE);
  my $archive = checkMakeBackup(fullBackup => 0);
  Test::File::file_mode_is($archive, 0600, 'Checking wether the archive permission only allow reads by its owner');
  my @op = `ls -l $archive`;
  diag "LS -l @op";


  my $backupDir = EBox::Backup->backupDir();
  Test::File::file_mode_is($backupDir, 0700, 'Checking wether the archives directory permission only allow reads by its owner');
}

1;
