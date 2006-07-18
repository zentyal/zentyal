package EBox::Global::TestStub;
# Description:
# 
use strict;
use warnings;

use Test::MockModule;
use EBox::GConfModule::TestStub;



sub setAllEBoxModules
{
  my (%modulesByName) = @_;  
  
  while (my ($name, $module)  = each %modulesByName) {
      setEBoxModule($name, $module);
  }

}

sub setEBoxModule
{
    my ($name, $module, $depends) = @_;

    EBox::GConfModule::TestStub::setEntry("/ebox/modules/global/modules/$name/class", $module);
    EBox::GConfModule::TestStub::setEntry("/ebox/modules/global/modules/$name/changed", undef);
    EBox::GConfModule::TestStub::setEntry("/ebox/modules/global/modules/$name/depends", $depends) if defined $depends;

}

sub clear
{
    my %config = @{ EBox::GConfModule::TestStub::dumpConfig() };

    my @globalKeys = grep { m{^/ebox/modules/global/}  } keys %config;
    foreach my $key (@globalKeys) {
	delete $config{$key};
    }
    
    EBox::GConfModule::TestStub::setConfig(%config);
}



my $globalModuleFaked;
sub fake
{
    if (defined $globalModuleFaked) {
	return;
    }

    EBox::GConfModule::TestStub::fake();
    $globalModuleFaked = new Test::MockModule('EBox::Global');

}

sub unfake
{
    if (!defined $globalModuleFaked) {
	die "Module not mocked" ;
    }

    $globalModuleFaked->unmock_all();
    $globalModuleFaked = undef;
}


1;
