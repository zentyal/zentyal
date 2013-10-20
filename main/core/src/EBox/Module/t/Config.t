use strict;
use warnings;

use Test::More tests => 12;
use Test::Exception;
use TryCatch;

use EBox::Global::TestStub;

EBox::Global::TestStub::fake();

use constant {
    MODULE_NAME => 'sysinfo',
    CONF_KEY    => 'testConfKey',
    STATE_KEY   => 'testStateKey',
};

my $fakeConfDir = '/tmp/zentyal-confchanged.test';

try {
    startup();
    setAsChangedTest();
    changeConfKeyTest();
    changeStateKeyTest();
    checkFileDump();
} catch ($e) {
    finalize();
    $e->throw();
}
finalize();

sub startup
{
    system ("rm -rf $fakeConfDir");

    my $global = EBox::Global->getInstance();
    if ($global->modIsChanged(MODULE_NAME)) {
        die 'This test needs that ' . MODULE_NAME . ' module is in a non-changed state';
    }

    system "mkdir -p $fakeConfDir";
    EBox::Config::TestStub::fake(conf => $fakeConfDir);
}

sub finalize
{
    my $mod = EBox::Global->modInstance(MODULE_NAME);
    $mod->unset(CONF_KEY);
    $mod->st_unset(STATE_KEY);

    system  "rm -rf $fakeConfDir";
}


sub setAsChangedTest
{
    my $mod = EBox::Global->modInstance(MODULE_NAME);
    $mod->setAsChanged();

    checkModuleChanged(1);

    lives_ok {
        $mod->revokeConfig();
    } 'checking if revoke config do not fail';
}


sub changeConfKeyTest
{
    my $mod = EBox::Global->modInstance(MODULE_NAME);
    $mod->set_int(CONF_KEY, 4);

    checkModuleChanged(1);

    lives_ok {
        $mod->revokeConfig();
    } 'checking if revoke config do not fail';
}

sub changeStateKeyTest
{
    my $mod     = EBox::Global->modInstance(MODULE_NAME);
    $mod->st_set_int(STATE_KEY, 4);

    checkModuleChanged(0);

    lives_ok {
        $mod->revokeConfig();
    } 'checking if revoke config do not fail';
}

sub checkModuleChanged
{
    my ($changeExpected) = @_;
    $changeExpected = $changeExpected ? 1 : 0;

    my $global = EBox::Global->getInstance();
    my $changeState = $global->modIsChanged(MODULE_NAME) ? 1 : 0;

    is $changeState, $changeExpected, 'Testing module change state';
}

sub checkFileDump
{
    my $mod = EBox::Global->modInstance(MODULE_NAME);

    $mod->set('test-key', 25);

    lives_ok { $mod->_dump_to_file() } 'Dumping backup file';

    my $bakFile = $mod->_bak_file_from_dir(EBox::Config::conf);

    is ((-f $bakFile), 1, 'Bak file is present');

    ok (((-s $bakFile) > 0), 'Bak file size is greater than zero');

    $mod->set('test-key', 66);

    is ($mod->get('test-key'), 66, 'Checking key value before loading dump');

    lives_ok { $mod->_load_from_file() } 'Loading backup file';

    is ($mod->get('test-key'), 25, 'Checking key value after loading dump');
}

1;
