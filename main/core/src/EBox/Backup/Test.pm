# Copyright (C) 2006-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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
use strict;
use warnings;

package EBox::Backup::Test;

use base 'EBox::Test::Class';

use lib '../..';

use EBox::Global::TestStub;
use EBox::TestStubs;

EBox::Global::TestStub::fake();

use EBox::Backup;

use Test::MockObject;
use Test::More skip_all => 'FIXME (disabled due too much fails in jenkins)';
use Test::Exception;
use Test::Differences;
use Test::File;
use EBox::Sudo::TestStub;

use EBox::Gettext;
use File::Slurp qw(read_file write_file);
use EBox::FileSystem qw(makePrivateDir);
use Perl6::Junction qw(all);

use Readonly;
Readonly::Scalar my $CANARY_CONF_KEY => 'canary_testkey';

use constant BEFORE_BACKUP_VALUE => 'beforeBackup';
use constant AFTER_BACKUP_VALUE  => 'afterBackup';

use constant BEFORE_BACKUP_NOCONF_VALUE => 'beforeBackupNoConf';
use constant AFTER_BACKUP_NOCONF_VALUE  => 'afterBackupNoConf';
use constant BUG_BACKUP_NOCONF_VALUE  => 'bugReport';

sub testDir
{
    return '/tmp/zentyal.backup.test';
}

sub ignoreZentyalVersionCheck : Test(startup)
{
    Test::MockObject->fake_module('EBox::Backup',
                                  '_checkZentyalVersion' => sub {},
                                 );
}

# needed for progress indicator stuff
sub setupProgressIndicatorHostModule : Test(setup)
{
    EBox::TestStubs::fakeModule(name => 'apache',
                subs => [
                            _regenConfig => sub {},
                        ],
                );
}

sub setupDirs : Test(setup)
{
    my ($self) = @_;

    return if !exists $INC{'EBox/Backup.pm'};

    EBox::TestStubs::setEBoxConfigKeys(conf => testDir(), tmp => $self->testDir(), group => 'ebox');

    my $testDir = $self->testDir();
    system "rm -rf $testDir";

    makePrivateDir($testDir);

    system "rm -rf /tmp/backup";
    ($? == 0) or die $!;
    makePrivateDir('/tmp/backup');
}

# this canary contains sensitive data so in debug
sub setupCanaryModule : Test(setup)
{
    my $canaryNoConf;
    EBox::TestStubs::fakeModule(
            name => 'canary',
            subs => [
                setCanary => sub { my ($self, $canary) = @_; $canaryNoConf = $canary },
                canary => sub { my ($self) = @_; return $canaryNoConf },
                dumpConfig => sub {
                    my ($self, $dir, %options) = @_;
                    EBox::Module::Config::_dump_to_file($self, $dir);
                    if ($options{bug}) {
                        write_file ("$dir/canary", BUG_BACKUP_NOCONF_VALUE );
                    }
                    else {
                        my $data = $self->canary();
                        $data or $data = '';
                        write_file ("$dir/canary", $data );
                    }
                },
                restoreConfig => sub {
                    my ($self, $dir) = @_;
                    EBox::Module::Config::_load_from_file($self, $dir);
                    my $backedUpData =  read_file ("$dir/canary");
                    $self->setCanary($backedUpData);
                },
                revokeConfig => sub {
                    _canaryRevokeConfig($CANARY_CONF_KEY);
                }
            ],
    );
}

sub banRootCommands : Test(setup)
{
    EBox::Sudo::TestStub::addCommandBanFilter('chown');
}

sub setConfigCanary
{
    my ($value) = @_;

    my $canaryConf = EBox::Global->modInstance('canary');
    $canaryConf->set($CANARY_CONF_KEY, $value);
    $canaryConf->setAsChanged();
}

sub setNoConfigCanary
{
    my ($value) = @_;
    my $canaryConf = EBox::Global->modInstance('canary');
    $canaryConf->setCanary($value);
    $canaryConf->setAsChanged();
}

sub _canaryRevokeConfig
{
    my ($key) = @_;

    EBox::Global->getInstance()->{redis}->set("/conf/canary/$key", AFTER_BACKUP_VALUE);
}

sub checkConfigCanary
{
    my ($expectedValue) = @_;

    my $canary = EBox::Global->modInstance('canary');
    my $value = $canary->get_string($CANARY_CONF_KEY);
    is ($value, $expectedValue, 'Checking Config data of simple module canary');
}

sub checkNoConfigCanary
{
    my ($expectedValue) = @_;
    my $canary = EBox::Global->modInstance('canary');
    my $extraConf = $canary->canary();
    is ($extraConf, $expectedValue, 'Checking extra no-config data of canary module');
}

sub teardownConfigCanary : Test(teardown)
{
    EBox::Global->modInstance('canary')->unset($CANARY_CONF_KEY);
}

sub teardownCanaryModule : Test(teardown)
{
    my ($self) = @_;
    EBox::TestStubs::setConfig();
}

# this counts for 3 tests
sub checkStraightRestore
{
    my ($archiveFile, $options_r, $msg) = @_;

    my $backup = new EBox::Backup();
    setConfigCanary(AFTER_BACKUP_VALUE);
    setNoConfigCanary(AFTER_BACKUP_NOCONF_VALUE);

    lives_ok { $backup->restoreBackup($archiveFile, @{ $options_r  }) } $msg;

    my %options = @{ $options_r  };
    my $bugReport = $options{bugReport};

    checkConfigCanary(BEFORE_BACKUP_VALUE);
    my $noConfigValue = $bugReport ? BUG_BACKUP_NOCONF_VALUE : BEFORE_BACKUP_NOCONF_VALUE;
    checkNoConfigCanary($noConfigValue);

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

    use Test::Differences;
    eq_or_diff [sort @modulesChanged], [sort @modules], $name;
}

# this counts for 2 tests
sub checkDeviantRestore
{
    my ($archiveFile, $options_r, $msg) = @_;

    my $backup = new EBox::Backup();
    setConfigCanary(AFTER_BACKUP_VALUE);
    setNoConfigCanary(AFTER_BACKUP_NOCONF_VALUE);
    dies_ok { $backup->restoreBackup($archiveFile, @{ $options_r  }) } $msg;

    diag "Checking that failed restore has not changed the configuration";
    checkConfigCanary(AFTER_BACKUP_VALUE, 1);
    checkNoConfigCanary(AFTER_BACKUP_NOCONF_VALUE, 1);
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
sub invalidArchiveTest : Test(15)
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

sub restoreConfigurationBackupTest : Test(6)
{
    my ($self) = @_;

    my $configurationBackup;
    setConfigCanary(BEFORE_BACKUP_VALUE);
    setNoConfigCanary(BEFORE_BACKUP_NOCONF_VALUE);
    $configurationBackup = checkMakeBackup(description => 'test configuration backup');
    checkStraightRestore($configurationBackup, [], 'configuration restore from a configuration backup');
}

sub restoreBugreportTest : Test(4)
{
    my ($self) = @_;

    my $backup = new EBox::Backup();
    my $bugReportBackup;

    setConfigCanary(BEFORE_BACKUP_VALUE);
    setNoConfigCanary(BEFORE_BACKUP_NOCONF_VALUE);
    lives_ok { $bugReportBackup = $backup->makeBugReport() } 'make a bug report';

    setConfigCanary(AFTER_BACKUP_VALUE);

    lives_ok { $backup->restoreBackup($bugReportBackup) } 'Restoring bug report';

    checkConfigCanary(BEFORE_BACKUP_VALUE);
    checkNoConfigCanary(BUG_BACKUP_NOCONF_VALUE);
}

sub partialRestoreTest : Test(5)
{
    my ($self) = @_;

    my $configurationBackup;
    setConfigCanary(BEFORE_BACKUP_VALUE);
    $configurationBackup = checkMakeBackup(description => 'test configuration backup');

    setConfigCanary(AFTER_BACKUP_VALUE);

    # bad case: not modules to restore
    dies_ok {
        EBox::Backup->restoreBackup($configurationBackup, modsToRestore => []);
    } 'called restoreBackup with a empty list of modules to restore';

    # bad case: inexistent module
    dies_ok {
        EBox::Backup->restoreBackup(
                $configurationBackup,
                modsToRestore => ['canary', 'inexistent'],
                );
    } 'called restoreBackup with a list of modules to restore which contains inexistent modules';

    my @modsToRestore = ('canary');
    lives_ok {
        EBox::Backup->restoreBackup(
                $configurationBackup,
                modsToRestore => \@modsToRestore,
                )
    } "Partial restore with modules @modsToRestore";

    checkConfigCanary(BEFORE_BACKUP_VALUE);
}

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

sub listBackupsTest : Test(3)
{
    my ($self) = @_;
    diag "The backup's details of id a are not tested for now. The date detail it is only tested as relative order";

    my $backup = new EBox::Backup();
    my @backupParams = (
            [description => 'configuration backup'],
            [description => 'second backup'],
            );

    setConfigCanary('indiferent configuration');

    foreach (@backupParams) {
        my $global = EBox::Global->getInstance();
        $global->saveAllModules();

        $backup->makeBackup(@{ $_ });
        sleep 1;
    }

    # add no-tar files in backup dir to test reliability
    my $backupsDir = $self->testDir() . '/backups';
    system "touch $backupsDir/noBackup";
    system "touch $backupsDir/1221";

    my @backups = @{$backup->listBackups()};
    is @backups, @backupParams, 'Checking number of backups listed';

    foreach my $backup (@backups) {
        my %backupParam = @{ pop @backupParams };
        my $awaitedDescription = $backupParam{description};

        is $backup->{description}, $awaitedDescription, 'Checking backup description';
    }
}

sub backupDetailsFromArchiveTest : Test(9)
{
    setConfigCanary(BEFORE_BACKUP_VALUE);
    my $global = EBox::Global->getInstance();
    $global->saveAllModules();

    my $configurationBackupDescription = 'test configuration backup for detail test';
    my $configurationBackup = EBox::Backup->makeBackup(description => $configurationBackupDescription) ;

    my $bugreportBackupDescription = 'Bug report'; # string found in EBox::Backup::makeBugReport
    my $bugreportBackup = EBox::Backup->makeBugReport();

    # XXX date detail IS NOT checked
    my %detailsExpectedByFile = (
            $configurationBackup => {
                description => $configurationBackupDescription,
                type        => $EBox::Backup::CONFIGURATION_BACKUP_ID,
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

sub backupWithChangesTest : Test(5)
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my @changedModules = grep {
        $global->modIsChanged($_);
    } @{ $global->modNames };
    $global->modChange('canary');

    setConfigCanary(BEFORE_BACKUP_VALUE);
    throws_ok {
        EBox::Backup->makeBackup(description => 'test');
    }  qr/The following modules have unsaved changes/, 'Checking wether the backup is forbidden with changed modules';

    setConfigCanary(AFTER_BACKUP_VALUE);

    checkConfigCanary(AFTER_BACKUP_VALUE, 1);

    checkModulesChanged(
            name => 'Check wether module changed state has not be changed',
            modules => \@changedModules,
    );

    lives_ok {
        EBox::Backup->makeBackup(description => 'test', fallbackToRO => 1);
    }  'Checking wether the backup  with changed modules is possible with fallback to read-only';
    checkConfigCanary(AFTER_BACKUP_VALUE, 0);
}

sub restoreFailedTest : Test(4)
{
    my ($self) = @_;

    # we force failure in one of the modules
    my $forcedFailureMsg  = 'forced failure ';
    EBox::TestStubs::fakeModule(
            name => 'unrestorableModule',
            subs => [
                restoreConfig => sub {
                    die $forcedFailureMsg;
                },
                revokeConfig => sub { },
            ],
    );

    my $global = EBox::Global->getInstance();

    setConfigCanary(BEFORE_BACKUP_VALUE);
    my $backupArchive = checkMakeBackup();

    setConfigCanary(AFTER_BACKUP_VALUE);

    $global->saveAllModules();
    foreach my $mod (@{ $global->modInstances }) {
        next if $mod->name eq 'apache'; # we dont use apache mmod
        $mod->setAsChanged();   # we mark modules as changed to be able to detect
        # revoked modules
    }

    throws_ok {
        my $b = new EBox::Backup;
        $b->restoreBackup($backupArchive);

    } qr /$forcedFailureMsg/, 'Checking wether restore failed as expected';

  SKIP: {
        skip 'Revoking is not yet working with our mocks', 2;

        diag "Checking modules for revoked values. We check only Config values because currently the revokation only takes care of them";
        checkConfigCanary(AFTER_BACKUP_VALUE);

        my @modules = @{$global->modNames()};

        my @modulesNotChanged =  grep { (not $global->modIsChanged($_)) } @modules;

        ok scalar @modulesNotChanged > 0, 'Checking wether after the restore failure' .
            ' some  modules not longer a changed state (this is a clue of revokation)' ;
    }
}

sub checkArchivePermissions : Test(3)
{
    my ($self) = @_;

    setConfigCanary(BEFORE_BACKUP_VALUE);
    my $archive = checkMakeBackup();
    Test::File::file_mode_is($archive, 0660, 'Checking wether the archive permission only allow reads by its owner');
    my @op = `ls -l $archive`;
    diag "LS -l @op";

    my $backupDir = EBox::Backup->backupDir();
    Test::File::file_mode_is($backupDir, 0700, 'Checking wether the archives directory permission only allow reads by its owner');
}

1;
