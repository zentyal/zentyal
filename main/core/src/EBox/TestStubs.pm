# Copyright (C) 2006-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::TestStubs;
use base 'Exporter';

# package: EBox::TestStubs
#
#  this package is the global facade to all zentyal-base test stubs
#
# warning:
# do NOT confuse with EBox::TestStub (this package is the teststub for the -package- EBox)
#

use Test::MockObject::Extends;

use EBox::Sudo::TestStub;
use EBox::TestStub;
use EBox::Config::TestStub;
use EBox::Module::Config::TestStub;
use EBox::Global::TestStub;
use EBox::NetWrappers::TestStub;
use EBox::Test::RedisMock;
use EBox::Exceptions::Internal;

our @EXPORT_OK = qw(activateEBoxTestStubs fakeModule setConfig setConfigKeys);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

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
    my @components = qw(EBox Sudo Config ModuleConfig Global NetWrappers); # they will be faked in this order

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
               'ModuleConfig' => \&EBox::Module::Config::TestStub::fake,
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

# Function: setConfig
#
#    Set EBox config keys. (Currently stored in redis)
#    Please do NOT confuse this sub with setEBoxConfigKeys
#
# Parameters:
#     the keys and values to be established
#
# Prerequisites:
#      activateEBoxTestStubs must be called to be able to use this function
# Usage examples:
#   setConfig(); # clear the current configuration
#       setConfig(
#         '/ebox/modules/openvpn/user'  => $UID,
#         '/ebox/modules/openvpn/group' =>  $gids[0],
#         '/ebox/modules/openvpn/conf_dir' => $confDir,
#         '/ebox/modules/openvpn/dh' => "$confDir/dh1024.pem",
#                ); # set some keys
#
sub setConfig
{
    return EBox::Module::Config::TestStub::setConfig(@_);
}

# Function: setConfigKey
#
#    set a EBox config key and his value. (Currently stored in redis)
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
    return EBox::Module::Config::TestStub::setEntry(@_);
}

# Function: setModule
#
#   Register an eBox module in eBox configuration. This is not needed
#   for modules created with fakeModule
#
# Parameters:
#   $name     - the module name
#   $package  - the perl module package
#   $depends  - a list reference with the module
#               dependencies (optional)
# Prerequisites:
#      activateEBoxTestStubs must be called to be able to use this function
# Usage examples:
#    setModule('openvpn' => 'EBox::OpenVPN');
sub setModule
{
    EBox::Global::TestStub::setModule(@_);
}

sub unsetModules
{
    EBox::Global::TestStub::clear();
}

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

# Function: fakeModule
#
#    Create on the fly fake eBox modules
#
# Parameters:
#       (named parameters)
#       name     - the name of the ebox module (required)
#       package  - the perl package of the ebox module (optional)
#       isa      - the parents of the package in addtion of EBox::Module::Config.
#                  May be a scalar (one addtional parent) or a reference to a
#                   list of parents (optional)
#       subs - the subs to be installed in the package; in the form of
#       a reference to a list containing the names and sub references
#       of each sub. (optional)
#       initializer - a initializer sub for the module. The module
#       constructor will call this sub passing itself as first
#       parameter. (optional, is not used if you provide a custom _create method)
#
#
# Prerequisites:
#      activateEBoxTestStubs must be called to be able to use this function
# Usage examples:
#   fakeModule(name => 'idleModule');
#       fakeModules(
#                name => 'macaco', package => 'EBox::Macaco',
#                subs => [ sayHello => sub { print 'hi'  }  ],
#       );
#
sub fakeModule
{
    my %params = @_;
    my $modName = $params{name};
    $modName or throw EBox::Exceptions::Internal('fakeModule: lacks name paramater');
    my $modPackage = exists $params{package} ? $params{package} :  'EBox::' . ucfirst $modName;
    my $initializerSub = exists $params{initializer} ? $params{initializer} : sub { my ($self) = @_; return $self};
    my %subs =  exists $params{subs} ? @{ $params{subs} } : ();

    my @isa = ('EBox::Module::Config');
    if (exists $params{isa} ) {
        my @extraIsa = ref $params{isa} ? @{ $params{isa} }  : ($params{isa});
        push @isa,  @extraIsa;
    }

    my $createIsaCode = 'package ' . $modPackage . "; use base qw(@isa);";
    eval $createIsaCode;
    die "When creating ISA array $@" if  $@;

    # add default methods if not supplied by the user
    if (not $subs{_create}) {
        $subs{_create} =  sub {
            my $self = EBox::Module::Config->_create(name => $modName,
                                                     redis => EBox::Test::RedisMock->new());
            bless $self, $modPackage;

            $self = $initializerSub->($self);
            return $self;
        }
    }

    Test::MockObject->fake_module($modPackage,  %subs,);

    setModule($modName, $modPackage);
}

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
#           'eth0' => {
#                   up => 1,
#                   address => {
#                       '192.168.3.4' => '255.255.255.0',
#                       },
#                  mac_address => '00:EE:11:CC:CE:8D',
#
#                 },
#           'eth1' => {
#                   up => 1,
#                   address => {
#                       '192.168.45.4' => '255.255.255.0',
#                       '10.0.0.7'     => '255.0.0.0',
#                       },
#                  mac_address => '00:11:11:CC:CE:8D',
#
#                 },
#           'eth2' => {
#                   up => 0,
#                   address => {
#                       '142.120.45.4' => '255.255.255.0',
#                       '44.0.0.7'     => '255.0.0.0',
#                       },
#                  mac_address => '00:11:11:CC:AA:8D',
#                 },
#
#          );
#
#   EBox::TestStubs::setFakeIfaces(@fakeIfaces);
sub setFakeIfaces
{
    my $params_r = { @_ };
    EBox::NetWrappers::TestStub::setFakeIfaces($params_r);
}

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
#       '192.168.45.0' => '0.0.0.0',
#       '0.0.0.0'      => '10.0.1.100',
#       '10.0.0.0'     => '192.168.45.123',
#          );
#
#  EBox::TestStubs::setFakeRoutes(@routes);
sub setFakeRoutes
{
    my $params_r = { @_ };
    EBox::NetWrappers::TestStub::setFakeRoutes($params_r);
}

1;
