# Description:
# 
use strict;
use warnings;

use Test::More tests => 20;
use Test::Exception;


use lib '../../..';

use EBox::TestStub;

use_ok 'EBox::Global::TestStub';

testStubsSetup();
getInstanceTest();
modInstanceTest();
changedTest();
clearTest();



sub testStubsSetup
{
    EBox::TestStub::fake();
    EBox::Global::TestStub::fake();
    EBox::Global::TestStub::setEBoxModule('baboon', 'EBox::Baboon');

      MOCK_CLASS:{
	  package EBox::Baboon;
	  use base 'EBox::GConfModule';
	  $INC{'EBox/Baboon.pm'} =1;
	  sub _create
	  {
	      my ($class, @optParams) = @_;
	      my $self = $class->SUPER::_create(name => 'baboon', @optParams);
	      return $self;
	      
	  }
     }
}





sub modInstanceTest
{
    my $global = EBox::Global->getInstance();
    
    foreach my $n  (0 .. 1) {
	my $baboonModule;
	lives_ok { $baboonModule = $global->modInstance('baboon') } 'modInstance';
	ok defined $baboonModule, 'Checking module returned by modInstance';
	isa_ok $baboonModule, 'EBox::GConfModule';
	isa_ok $baboonModule, 'EBox::Baboon';
   }

}

sub getInstanceTest
{
    my $global;

    foreach my $n (0 .. 1) {
	foreach my $readonly (0, 1) {
	    lives_ok { $global = EBox::Global->getInstance($readonly) } 'EBox::Global::getInstance';
	    isa_ok $global, 'EBox::Global';
	}
    }

}

sub changedTest
{
    my  $baboonModule = EBox::Global->modInstance('baboon');
    defined $baboonModule or die "Cannot get a baboon module";
    my $global = EBox::Global->getInstance();

    $global->modChange('baboon');
    ok $global->modIsChanged('baboon'), 'Checking modChange and modIsChanged';
    $global->modRestarted('baboon');
    ok !$global->modIsChanged('baboon'), 'Checking modRestarted and modIsChanged';
}


sub clearTest
{
    my %originalConfig = (
		      '/ebox/unrelatedToGlobal/bool'    => 1,
		      '/ebox/unrelatedToGlobal/integer' => 100,
		      '/anotherApp/string'              => 'a string',
	  );
    EBox::GConfModule::TestStub::setConfig(%originalConfig); 

    EBox::Global::TestStub::setEBoxModule('baboon', 'EBox::Baboon');
    EBox::Global::TestStub::setEBoxModule('mandrill', 'EBox::Mandrill');


    EBox::Global::TestStub::clear();
    my %actualConfig = @{ EBox::GConfModule::TestStub::dumpConfig() };
    is_deeply(\%actualConfig, \%originalConfig, 'Checking that all keys of module global are remvoed from the config and the rest is left untouched');
}

1;
