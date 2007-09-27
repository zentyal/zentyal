package EBox::TestStubs;
use base 'Exporter';
# package: EBox::TestStubs
#
#  this package is the global facade to all ebox-base test stubs
#
# warning:
# do NOT confuse with EBox::TestStub (this package is the teststub for the -package- EBox)
#
use strict;
use warnings;

use Test::MockObject::Extends;

use EBox::Sudo::TestStub;
use EBox::TestStub;
use EBox::Config::TestStub;
use EBox::GConfModule::TestStub;
use EBox::Global::TestStub;
use EBox::NetWrappers::TestStub;


our @EXPORT_OK = qw(activateEBoxTestStubs fakeEBoxModule setConfig setConfigKeys);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

#
# Function: activateTestStubs
#
#   Some of the parts of eBox need to be replaced with tests stubs for
#   an easy testing. This sub is intended for do this setup in only
#   one place. Please notice test classes created using
#   EBox::Test::Class automatically call this function
#
# Parameters: 
#     There are optional parameters only intended for advanced
#     usage; each of the test stub may be controlled with two
#     parameters.
#
#        "fake$componentName" - whether to activate the teststub for
#        this component or not (default: true)
#        "$componentName" - an array ref with extra parameters for the
#        component. (optional) 
#
# See also:
#     <EBox::Test::Class>
#
# 
sub activateTestStubs
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
# Function: setConfig
#
#    Set EBox config keys. (Currently stored in GConf)
#    Please do NOT confuse this sub with setEBoxConfigKeys
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
# Function: setConfigKey
#
#    set a EBox config key and his value. (Currently stored in GConf)
#    Plese do not confuse this sub with setEBoxConfigKeys
#
# Parameters:
#     the key and value to be established
#
# Prerequisites:
#      activateEBoxTestStubs must be called to be able to use this function
# Usage examples:
#       setConfigKey( '/ebox/modules/openvpn/user'  => $UID)
sub setConfigKey
{
  return EBox::GConfModule::TestStub::setEntry(@_); 
}

#
# Function: setEBoxModule
#
#   Register an eBox module in eBox configuration. This is not needed
#   for modules created with fakeEBoxModule
#
# Parameters:
#   $name     - the module name
#   $package  - the perl module package
#   $depends  - a list reference with the module
#               dependencies (optional)
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
#   Set the keys and values of configuration values accessed via
#   EBox::Config. Don't confuse this configuration values with
#   ''normal'' eBox configuration that is retrevied using module
#   methods, for fake those last configuration you can use
#   EBox::Test::setConfig
#   If you try to establish an inexistent key, an error will be raised
#
#
# Parameters:
#    the keys and values to be established, at least you must supply a pair
#
# Prerequisites:
#      activateEBoxTestStubs must be called to be able to use this function
# Usage examples:
#    setEboxConfigKeys(locale => 'es', group => 'ebox', css => '/var/www/css', lang => 'cat') 
sub setEBoxConfigKeys
{
  return EBox::Config::TestStub::setConfigKeys(@_);
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
#       isa      - the parents of the package in addtion of EBox::GConfModule.
#                  May be a scalar (one addtional parent) or a reference to a
#                   list of parents (optional)
#       subs - the subs to be installed in the package; in the form of
#       a reference to a list containing the names and sub references
#       of each sub. (optional)
#       initializer - a initializer sub for the module. The module
#       constructor will call this sub passing itself as first
#       parameter. (optional)
#
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
  if (exists $params{isa} ) {
    my @extraIsa = ref $params{isa} ? @{ $params{isa} }  : ($params{isa});
    push @isa,  @extraIsa;
  }

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
# Function: setFakeIfaces
#
#    Set fake computer network interfaces. This ifaces will used by
#    EBox::NetWrappers methods
#
# Parameters:
#
#     a list with pairs of interfaces names and
#     attributes. The name is a string and the attributes is a hash
#     ref with the following elements:
#
#       up - boolean value 
#       address - hash reference to a hash with IP
#                 addresses as keys and netmasks as values
#       mac_address - string with the mac address
#
# Prerequisites:
#      activateEBoxTestStubs must be called to be able to use this function
# Usage examples:
#   my @fakeIfaces = (
# 		    'eth0' => {
# 			        up => 1,
# 			        address => {
# 					    '192.168.3.4' => '255.255.255.0',
# 					    },
# 			       mac_address => '00:EE:11:CC:CE:8D',
#
# 			      },
# 		    'eth1' => {
# 			        up => 1,
# 			        address => {
# 					    '192.168.45.4' => '255.255.255.0',
# 					    '10.0.0.7'     => '255.0.0.0',
# 					    },
# 			       mac_address => '00:11:11:CC:CE:8D',
#
# 			      },
# 		    'eth2' => {
# 			        up => 0,
# 			        address => {
# 					    '142.120.45.4' => '255.255.255.0',
# 					    '44.0.0.7'     => '255.0.0.0',
# 					    },
# 			       mac_address => '00:11:11:CC:AA:8D',
# 			      },
#
# 		   );
#
#   EBox::TestStubs::setFakeIfaces(@fakeIfaces);
sub setFakeIfaces
{
  my $params_r = { @_ };
  EBox::NetWrappers::TestStub::setFakeIfaces($params_r);
}


#
# Function: setFakeRoutes
#
#   Set fake computer network routes. This fake routes will used by
#   EBox::NetWrappers functions 
#
# Parameters:
#     a list with pairs of network destination and gateways
#
# Prerequisites:
#      activateEBoxTestStubs must be called to be able to use this function
# Usage example:
#  my @routes = (
#		'192.168.45.0' => '0.0.0.0',
#		'0.0.0.0'      => '10.0.1.100',
#		'10.0.0.0'     => '192.168.45.123',
#	       );
#
#  EBox::TestStubs::setFakeRoutes(@routes);
sub setFakeRoutes
{
  my $params_r = { @_ };
  EBox::NetWrappers::TestStub::setFakeRoutes($params_r);
}

1;
