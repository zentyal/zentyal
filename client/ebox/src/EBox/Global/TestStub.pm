package EBox::Global::TestStub;
# Description:
# 
use strict;
use warnings;

use Test::MockObject;
use Params::Validate;
use EBox::Global;
use EBox::GConfModule::TestStub;


my %modulesInfo;

sub setAllEBoxModules
{
  my (%modulesByName) = @_;  
  
  while (my ($name, $module)  = each %modulesByName) {
      setEBoxModule($name, $module);
  }

}

sub setEBoxModule
{
    my ($name, $class, $depends) = @_;
    validate_pos(@_ ,1, 1, 0);

    defined $depends or
        $depends = [];
        

    $modulesInfo{$name} = {
        class => $class,
        depends => $depends,
        changed => 0,
       };



}

sub clear
{
    %modulesInfo = ();
}

sub _fakedReadModInfo
{
    my ($name) = @_;

    if (exists $modulesInfo{$name}) {
        return $modulesInfo{$name};
    }

    return undef;
}


sub  _fakedWriteModInfo
{
    my ($self, $name, $info) = @_;

    $modulesInfo{$name} = $info;
}


sub _fakedModNames
{
    return [keys %modulesInfo];
}

sub fake
{
    EBox::GConfModule::TestStub::fake(); # needed by some method, like changed
                                         # state of modules
    Test::MockObject->fake_module('EBox::Global',
                                  readModInfo => \&_fakedReadModInfo,
                                  writeModInfo => \&_fakedWriteModInfo,
                                  modNames     => \&_fakedModNames,
                              );

    
}

# only for interface completion
sub unfake
{
}


1;
