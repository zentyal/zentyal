package main;
#
use strict;
use warnings;


use Test::More tests => 8;
use Test::Exception;
use Error qw(:try);
use EBox;
use EBox::Global;
use EBox::Config::TestStub;


use constant {
  MODULE_NAME => 'apache',
  CONF_KEY    => 'testConfKey',
  STATE_KEY   => 'testStateKey',  

};


try {
  startup();
  setAsChangedTest();
  changeConfKeyTest();
  changeStateKeyTest();
}
finally {
  finalize();
};

sub warning
{
  diag 'This test may modify your eBox configuration';
  diag 'Do NOT use it in production environments';

}

sub _fakeConfDir
{
  return "/tmp/gconfchanged.test";
}

sub startup
{
  warning();

  my $fakeConfDir = _fakeConfDir();
  system  "rm -rf $fakeConfDir";

  EBox::init();
  
  
  my $global = EBox::Global->getInstance();
  if ($global->modIsChanged(MODULE_NAME)) {
    die 'This test needs that ' . MODULE_NAME . ' module is in a non-changed state';
  }

  
  system "mkdir -p $fakeConfDir";
  EBox::Config::TestStub::fake(conf => $fakeConfDir);
}

sub finalize
{
  my $mod     = EBox::Global->modInstance(MODULE_NAME);
  $mod->unset(CONF_KEY);
  $mod->st_unset(STATE_KEY);
}


sub setAsChangedTest # 3
{
  my $mod     = EBox::Global->modInstance(MODULE_NAME);
  $mod->setAsChanged();

  checkModuleChanged(1);

  lives_ok {
    $mod->revokeConfig(); 
  } 'checking if revoke config do not fail';
}


sub changeConfKeyTest # 3 
{
  my $mod     = EBox::Global->modInstance(MODULE_NAME);
  $mod->set_int(CONF_KEY, 4);

  checkModuleChanged(1);

  lives_ok {
    $mod->revokeConfig(); 
  } 'checking if revoke config do not fail';
}


sub changeStateKeyTest # 2 ch
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


  if ( $changeExpected) {
    checkBakFile(1, 'Checking bak file for expcted changed module');
  }

}


sub checkBakFile
{
  my ($bakFileExpected, $msg) = @_;

  my $mod     = EBox::Global->modInstance(MODULE_NAME);
  my $bakFile = $mod->_bak_file_from_dir(EBox::Config::conf);
  my $bakFilePresent = ( -f $bakFile) ? 1 : 0;

  is $bakFilePresent, $bakFileExpected, $msg;
}



1;
