use strict;
use warnings;

use Test::More tests => 49;
use Test::Exception;


use lib '../../';
use_ok('EBox::Test');

lives_ok { EBox::Test::activateEBoxTestStubs() } 'Activating ebox test stubs';
fakeEBoxModuleTest();


sub fakeEBoxModuleTest
{
  my $mod;

  EBox::Test::fakeEBoxModule(name => 'macaco');
  _testModuleBasics('macaco', 'EBox::Macaco');
  
  EBox::Test::fakeEBoxModule(name => 'macacoAnidado', package => 'EBox::Macaco::Macaco');
  _testModuleBasics('macacoAnidado', 'EBox::Macaco::Macaco');
  
  EBox::Test::fakeEBoxModule(name => 'macacoObservador', package => 'EBox::Macaco::Observador', isa => ['EBox::LogObserver']);
  $mod = _testModuleBasics('macacoObservador', 'EBox::Macaco::Observador');
  isa_ok($mod, 'EBox::LogObserver');

  EBox::Test::fakeEBoxModule(name => 'macacoSon', package => 'EBox::Macaco::Son', isa => ['EBox::Macaco']);
  $mod = _testModuleBasics('macacoSon', 'EBox::Macaco::Son');
  isa_ok($mod, 'EBox::Macaco');

  EBox::Test::fakeEBoxModule(name => 'macacoGrandson', package => 'EBox::Macaco::Son::Son', isa => ['EBox::Macaco::Son']);
  $mod = _testModuleBasics('macacoGrandson', 'EBox::Macaco::Son::Son');
  isa_ok($mod, 'EBox::Macaco::Son');
  isa_ok($mod, 'EBox::Macaco');

  EBox::Test::fakeEBoxModule(name => 'macacoObservadorSon', package => 'EBox::Macaco::Son::Observador', isa => ['EBox::Macaco', 'EBox::LogObserver']);
  $mod = _testModuleBasics('macacoObservadorSon', 'EBox::Macaco::Son::Observador');
  isa_ok($mod, 'EBox::Macaco');  
  isa_ok($mod, 'EBox::LogObserver');  
  can_ok($mod,  qw(domain tableInfo logHelper)); # EBox::LogObserver subs

  my %subs = (
	      'identity' => sub { my ($self, $param) =@_;  return $param  },
	      'zero'     => sub { return 0  },
	     );

  EBox::Test::fakeEBoxModule(name => 'macacoObservadorSonSubs', package => 'EBox::Macaco::Son::Observador::Subs', isa => ['EBox::Macaco', 'EBox::LogObserver'], subs => [%subs]);
  $mod = _testModuleBasics('macacoObservadorSonSubs', 'EBox::Macaco::Son::Observador::Subs');
  isa_ok($mod, 'EBox::Macaco');  
  isa_ok($mod, 'EBox::LogObserver');
  can_ok($mod, keys %subs, qw(domain tableInfo logHelper)); # installed extra subs + EBox::LogObserver subs
  is   EBox::Macaco::Son::Observador::Subs::zero(), 0, "Checking class call of the identity installed sub";
  is $mod->identity('mono'), 'mono', "Checking object call of the identity installed sub";

  my $initializerSub = sub { my ($self) =@_; $self->{partners} = 7  };
  EBox::Test::fakeEBoxModule(name => 'macacoGroomingPartners', package => 'EBox::Macaco::WithGroomingPartners', isa => ['EBox::Macaco'], subs => [ partners => sub { my $self = shift; return $self->{partners}}], initializer => $initializerSub);
  $mod = _testModuleBasics('macacoGroomingPartners', 'EBox::Macaco::WithGroomingPartners');
  isa_ok($mod, 'EBox::Macaco');  
  can_ok($mod, 'partners'); 
  is   $mod->partners(), 7, "Checking data initialization via object call of installed sub ";



}

sub _testModuleBasics
{
  my ($module, $package) = @_;

  diag "Module basics test for  $module";

  eval "use $package";
  ok !$@, "Checking loading of $package $@";

  my $mod;
  lives_ok {  $mod = EBox::Global->modInstance($module) } "Checking creation of a module instance using the global module";

  isa_ok($mod, 'EBox::GConfModule');
  isa_ok($mod, $package);
 
  return $mod;
}


1;
