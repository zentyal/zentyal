# Description:
# 
use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;
use Test::MockClass('EBox::Baboon', '0.2');

use lib '../../..';

use EBox::Mock;

use_ok 'EBox::Global::Mock';

mocksSetup();
getInstanceTest();
modInstanceTest();
changedTest();

my $baboonMockClass;

sub mocksSetup
{
    EBox::Mock::mock();
    EBox::Global::Mock::mock();
    EBox::Global::Mock::setEBoxModule('baboon', 'EBox::Baboon');

      $baboonMockClass = Test::MockClass->new('EBox::Baboon');
      $baboonMockClass->inheritFrom('EBox::GConfModule');
       my $baboonCreateMethod_r =  sub {
	  my ($class, @optParams) = @_;

	  # XXX i hope that the unability to use SUPER:: correctly is the result of a error of myself or a side efecct of Test::MockClass and that the nromal modu;les will not have any problem when instantiated by a mocked EBox::Global
# 	  my $self = $class->SUPER::_create(name => 'baboon', @optParams);
	  my $self = EBox::GConfModule::_create($class, name => 'baboon', @optParams);

	  return $self;
      };
      
      $baboonMockClass->addMethod('_create' => $baboonCreateMethod_r);
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
    defined $baboonModule or die "Can not get a baboon module";
    my $global = EBox::Global->getInstance();

    $global->modChange('baboon');
    ok $global->modIsChanged('baboon'), 'Checking modChange and modIsChanged';
    $global->modRestarted('baboon');
    ok !$global->modIsChanged('baboon'), 'Checking modRestarted and modIsChanged';
}


1;
