package EBox::Global::Mock;
# Description:
# 
use strict;
use warnings;

use Test::MockModule;
use EBox::GConfModule::Mock;



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

    EBox::GConfModule::Mock::setArbitraryEntry("/ebox/modules/global/modules/$name/class", $module);
    EBox::GConfModule::Mock::setArbitraryEntry("/ebox/modules/global/modules/$name/changed", undef);
    EBox::GConfModule::Mock::setArbitraryEntry("/ebox/modules/global/modules/$name/depends", $depends) if defined $depends;

}

sub clear
{
    my %config = @{ EBox::GConfModule::Mock::dumpConfig() };

    my @globalKeys = grep { m{^/ebox/modules/global/}  } keys %config;
    foreach my $key (@globalKeys) {
	delete $config{$key};
    }
    
    EBox::GConfModule::Mock::setConfig(%config);
}



my $globalModuleMocked;
sub mock
{
    if (defined $globalModuleMocked) {
	return;
    }

    EBox::GConfModule::Mock::mock();
    $globalModuleMocked = new Test::MockModule('EBox::Global');

}

sub unmock
{
    if (!defined $globalModuleMocked) {
	die "Module not mocked" ;
    }

    $globalModuleMocked->unmock_all();
    $globalModuleMocked = undef;
}


1;
