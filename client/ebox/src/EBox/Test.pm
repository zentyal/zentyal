# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package EBox::Test;
use base 'Exporter';

use Test::More;
use Test::Builder;
use Test::MockObject::Extends;
use Error qw(:try);


use EBox::Sudo::TestStub;
use EBox::TestStub;
use EBox::Config::TestStub;
use EBox::GConfModule::TestStub;
use EBox::Global::TestStub;
use EBox::NetWrappers::TestStub;

our @EXPORT_OK = qw(checkModuleInstantiation activateEBoxTestStubs fakeEBoxModule setConfig setConfigKeys);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );


my $Test = Test::Builder->new;

#
# Function: checkModuleInstantiation
#
#    Checks we can use the module package correctly (like Test::More::use_ok) and that we can instantiate correctly using the methods from EBox::Global.
#   That counts as 1 test for the plan.
#   		
#
# Parameters:
#         $moduleName    - name of the module
#         $modulePackage - package of the module
#
# Usage example:
#    checkModuleInstantiation('dhcp', 'EBox::DHCP');
#
sub checkModuleInstantiation 
{
    my ($moduleName, $modulePackage) = @_;

    eval  "use  $modulePackage";
    if ($@) {
	$Test->ok(0, "$modulePackage failed to load");
	$Test->diag("Error: $@");
	return;
    }
 
    my $global = EBox::Global->getInstance();
    defined $global or die "Can not get a instance of the global module";
	
    my $instance;
    my $modInstanceError = 0;

    try {
	$instance = $global->modInstance($moduleName);
    }
    otherwise {
	$modInstanceError = 1;;
    };
    
    if ($modInstanceError or !defined $instance) {
	$Test->ok(0, "Can not create a instance of the EBox's module $moduleName");
	return;
    }

    my $refType = ref $instance;

    if ($refType eq $modulePackage) {
	$Test->ok(1, "$moduleName instantiated correctly");
    }
    elsif (defined $refType) {
	$Test->ok(0, "The instance returned of $moduleName is not of type $modulePackage instead is a $refType");
    }
    else {
	$Test->ok(0, "The instance returned of $moduleName is not a blessed reference");
    }

}


#
# Function: activateEBoxTestStubs
#
#   Some of the parts of eBox needs to be replaced with tests stubs for ease testing. This sub is for do this setup in only one place.
#  Please note, test classes created using EBox::Test::Class automatically call this function
#
# Parameters:
#     There are optional parameters  only intended for advanced usage; each of the test stub may be controlled with two parameters.
#        "fake$componentName" - wether to activate the teststub for this component or not (default: true)
#        "$componentName"     - a array ref with extra parameters for the component. (optional)
#
#
# See also:
#     EBox::Test::Class
#
# 
sub activateEBoxTestStubs
{
    my %params = @_;
    my @components = qw(EBox Sudo Config GConfModule Global NetWrappers); # they will be faked in this order
    # set default parameters
    foreach my $stub (@components) {
      my $fakeSwitch = "fake$stub";
      $params{$fakeSwitch} = 1   if (!exists $params{$fakeSwitch});
      $params{$stub}       = []  if (!exists $params{$stub});
	 
    }

    my %fakeByComponent = (
			   'EBox'        => \&EBox::TestStub::fake,
			   'Sudo'        => \&EBox::Sudo::TestStub::fake,
			   'Config'      => \&EBox::Config::TestStub::fake,
			   'GConfModule' => \&EBox::GConfModule::TestStub::fake,
			   'Global'      => \&EBox::Global::TestStub::fake,
			   'NetWrappers' => \&EBox::NetWrappers::TestStub::fake,
			  );


    foreach my $comp (@components) {
      my $fakeSub_r = $fakeByComponent{$comp};
      defined $comp or throw EBox::Exceptions::Internal("No fake sub supplied for $comp");
      my $fakeSwitch = "fake$comp";
      if ($params{$fakeSwitch}) {
	my $fakeParams = $params{$comp};
	$fakeSub_r->(@{ $fakeParams  });
      }
    }
}

#
# Function: fakeEBoxModule
#
#    Create on the fly fake eBox modules
#
# Parameters:
#       (named parameters)
#       name     - the name of the ebox module (required)
#       package  - the perl package of the ebox module (optional)
#       isa      - the parents of the package (optional. Default: EBox:GConfModule)
#       subs     - the subs to be installed in the package; in the form of a reference to a list containig the names and sub references of each sub. (optional)
#       initalizer - a initializer sub for the module. The module constructor will call this sub passing itself as first parameter. (optional)
#
# Prerequisites:
#      activateEBoxTestStubs must be called to be able to use this function
# Usage examples:
#	fakeEBoxModule(name => 'idleModule');
#       fakeEBoxModules( 
#                name => 'macaco', package => 'EBox::Macaco', 
#                subs => [ sayHello => sub { print 'hi'  }  ],
#       );
# 
sub fakeEBoxModule
{
  my %params = @_;
  exists $params{name} or throw EBox::Exceptions::Internal('fakeEBoxModule: lacks name paramater');
  exists $params{package} or $params{package} =  'EBox::' . ucfirst $params{name};

  my @isa = ('EBox::GConfModule');
  push @isa, @{ $params{isa} } if exists $params{isa};
  my $createIsaCode =  'package ' . $params{package} . "; use base qw(@isa);";
  eval $createIsaCode;
  die "When creating ISA array $@" if  $@;

  my $initializerSub = exists $params{initializer} ? $params{initializer} : sub { my ($self) = @_; return $self};


  Test::MockObject->fake_module($params{package},
				_create => sub {
				  my $self = EBox::GConfModule->_create(name => $params{name});
				  bless $self, $params{package};
				  $self = $initializerSub->($self);
				  return $self;
				},
				@{ $params{subs} }
			       );



  EBox::Global::TestStub::setEBoxModule($params{name} => $params{package});
}

#
# Function: setConfig
#
#    set EBox config keys. (Currently stored in GConf)
#    Plese do not confuse this sub with setEBoxConfigKeys
#
# Parameters:
#     the keys and values to be established
#
# Prerequisites:
#      activateEBoxTestStubs must be called to be able to use this function
# Usage examples:
#	setConfig(); # clear the current configuration
#       setConfig(
# 		  '/ebox/modules/openvpn/user'  => $UID,
# 		  '/ebox/modules/openvpn/group' =>  $gids[0],
# 		  '/ebox/modules/openvpn/conf_dir' => $confDir,
# 		  '/ebox/modules/openvpn/dh' => "$confDir/dh1024.pem",
#                ); # set some keys	
# 
sub setConfig
{
  return EBox::GConfModule::TestStub::setConfig(@_); 
}

#
# Function: setEBoxModule
#
#   Register a ebox module in ebox configuration. This is not needed for modules created with fakeEBoxModule
#
# Parameters:
#   $name     - the name of the module
#   $package  - the perl package of the module
#   $depends  - a list refrence with the module dependencies (optional)#

# Prerequisites:
#      activateEBoxTestStubs must be called to be able to use this function
# Usage examples:
#    setEBoxModule('openvpn' => 'EBox::OpenVPN');
sub setEBoxModule
{
  return EBox::Global::TestStub::setEBoxModule(@_);
}

#
# Function: setEBoxConfigKeys
#
#   Set the keys and values of configuration values accessed via EBox::Config. Don't confuse this configuration vlaues with 'normal' eBox configuration that is retrevied using module methods, for fake those last configuration you can use EBox::Test::setConfig
#   If you try to establsih a inexistent key, a error will be raised
#
#
# Parameters:
#    the keys and values to be established, at least you must supply a pair
#
# Prerequisites:
#      activateEBoxTestStubs must be called to be able to use this function
# Usage examples:
#    setEboxConfigKeys(locale => 'es', group => 'ebox', css => '/var/ww/css', lang => 'cat') 
sub setEBoxConfigKeys
{
  return EBox::Config::TestStub::setConfigKeys(@_);
}


1;
