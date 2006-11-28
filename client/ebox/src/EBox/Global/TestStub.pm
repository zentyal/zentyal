package EBox::Global::TestStub;
# Description:
# 
use strict;
use warnings;

use EBox::GConfModule::TestStub;
use Params::Validate;


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
    validate_pos(@_ ,1, 1, 0);

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




sub fake
{
  EBox::GConfModule::TestStub::fake(); # just to be sure..
}

# only for interface completion
sub unfake
{
}


1;
