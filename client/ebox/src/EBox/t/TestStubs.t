use strict;
use warnings;

use Test::More tests => 78;
use Test::Exception;


use lib '../../';
use_ok('EBox::TestStubs');

lives_ok { EBox::TestStubs::activateTestStubs() } 'Activating ebox test stubs';
fakeEBoxModuleTest();


sub fakeEBoxModuleTest
{
  my $mod;

  EBox::TestStubs::fakeEBoxModule(name => 'macaco');
  _testModuleBasics('macaco', 'EBox::Macaco');
  
  EBox::TestStubs::fakeEBoxModule(name => 'eboxModuleAnidado', package => 'EBox::Module::Module');
  _testModuleBasics('eboxModuleAnidado', 'EBox::Module::Module');
  
  EBox::TestStubs::fakeEBoxModule(name => 'idleObserver', package => 'EBox::Idle::Observer', isa => ['EBox::LogObserver']);
  $mod = _testModuleBasics('idleObserver', 'EBox::Idle::Observer');
  isa_ok($mod, 'EBox::LogObserver');

  EBox::TestStubs::fakeEBoxModule(name => 'macacoSon', package => 'EBox::Macaco::Son', isa => ['EBox::Macaco']);
  $mod = _testModuleBasics('macacoSon', 'EBox::Macaco::Son');
  isa_ok($mod, 'EBox::Macaco');

  EBox::TestStubs::fakeEBoxModule(name => 'macacoGrandson', package => 'EBox::Macaco::Son::Son', isa => ['EBox::Macaco::Son']);
  $mod = _testModuleBasics('macacoGrandson', 'EBox::Macaco::Son::Son');
  isa_ok($mod, 'EBox::Macaco::Son');
  isa_ok($mod, 'EBox::Macaco');

  EBox::TestStubs::fakeEBoxModule(name => 'macacoObservadorSon', package => 'EBox::Macaco::Son::Observador', isa => ['EBox::Macaco', 'EBox::LogObserver']);
  $mod = _testModuleBasics('macacoObservadorSon', 'EBox::Macaco::Son::Observador');
  isa_ok($mod, 'EBox::Macaco');  
  isa_ok($mod, 'EBox::LogObserver');  
  can_ok($mod,  qw(domain tableInfo logHelper)); # EBox::LogObserver subs

  my %subs = (
	      'identity' => sub { my ($self, $param) =@_;  return $param  },
	      'zero'     => sub { return 0  },
	     );

  EBox::TestStubs::fakeEBoxModule(name => 'macacoObservadorSon-withSubs', package => 'EBox::Macaco::Son::Observador::Subs', isa => ['EBox::Macaco', 'EBox::LogObserver'], subs => [%subs]);
  $mod = _testModuleBasics('macacoObservadorSon-withSubs', 'EBox::Macaco::Son::Observador::Subs');
  isa_ok($mod, 'EBox::Macaco');  
  isa_ok($mod, 'EBox::LogObserver');
  can_ok($mod, keys %subs, qw(domain tableInfo logHelper)); # installed extra subs + EBox::LogObserver subs
  is   EBox::Macaco::Son::Observador::Subs::zero(), 0, "Checking class call of the identity installed sub";
  is $mod->identity('mono'), 'mono', "Checking object call of the identity installed sub";

  my $initializerSub = sub { my ($self) =@_; $self->{partners} = 7 ; return $self };
  EBox::TestStubs::fakeEBoxModule(name => 'macacoGroomingPartners', package => 'EBox::Macaco::WithGroomingPartners', isa => ['EBox::Macaco'], subs => [ partners => sub { my $self = shift; return $self->{partners}}], initializer => $initializerSub);
  $mod = _testModuleBasics('macacoGroomingPartners', 'EBox::Macaco::WithGroomingPartners');
  isa_ok($mod, 'EBox::Macaco');  
  can_ok($mod, 'partners'); 
  is   $mod->partners(), 7, "Checking data initialization via object call of installed sub ";

  _testModInstancesOfType('EBox::Inexistent', 0);
  _testModInstancesOfType('EBox::Macaco::Son::Son', 1);
  _testModInstancesOfType('EBox::Macaco', 6); 
 
}

sub _testModuleBasics
{
  my ($module, $package) = @_;

  diag "Module basics test for  $module";

  eval "use $package";
  ok !$@, "Checking loading of $package $@";

  my $global = EBox::Global->getInstance();

  ok $global->modExists($module), "Checking wether global module is aware of the existence of $module";

  my $mod;
  lives_ok {  $mod = EBox::Global->modInstance($module) } "Checking creation of a module instance using the global module";

  isa_ok($mod, 'EBox::GConfModule');
  isa_ok($mod, $package);


  
  my @modNames = @{ $global->modNames()  };
  my $nameFound = grep { $module eq $_ } @modNames;
  ok $nameFound, "checking wether EBox::Global::modNames returns correclty the module's name";
 

  if (! $nameFound) {
    my @modules = @ {$global->modNames() };
    diag "DEBUG. EBox::Global->modNames() -> @modules\n";
    my @alldirsBase = @{ $global->all_dirs_base('modules')   };
    diag "DEBUG. EBox::Global->allDirsBase() -> @alldirsBase\n";
    my @alldirs =  $global->all_dirs('modules')  ;
    diag "DEBUG. EBox::Global->allDirs() -> @alldirs\n";
  }

  return $mod;
}


sub _testModInstancesOfType
{
  my ($type, $instancesExpected) = @_;

  my $global =  EBox::Global->getInstance();
  my @instances;
  lives_ok{  @instances =  @{$global->modInstancesOfType($type) }  } 'EBox::Global::modInstancesOfType';

  is @instances, $instancesExpected, 'Checking wether modInstancesOfType returns the expected number of modules intances';

  if (@instances != $instancesExpected) {
    my @modules = @ {$global->modNames() };
    diag "DEBUG. EBox::Global->modNames() -> @modules\n";
    my @alldirsBase = @{ $global->all_dirs_base('modules')   };
    diag "DEBUG. EBox::Global->allDirsBase() -> @alldirsBase\n";
    my @alldirs =  $global->all_dirs('modules')  ;
    diag "DEBUG. EBox::Global->allDirs() -> @alldirs\n";
  }


 SKIP:{
    skip $instancesExpected, 'modInstancesOfType has not returned the expected dunmber of instances so we skip the instances checks' if @instances != $instancesExpected;

    foreach my $mod (@instances) {
      isa_ok ($mod, $type);
    }

  }

}


1;
