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



sub activateEBoxTestStubs
{
    my %params = @_;
    foreach my $stub (qw(EBox Sudo Config GConfModule Global NetWrappers)) {
	 $params{$stub} = []  if (!exists $params{$stub});
    }

    EBox::Sudo::TestStub::fake( @{ $params{Sudo} } );
    EBox::TestStub::fake( @{ $params{EBox} } );
    EBox::Config::TestStub::fake( @{ $params{Config} } );
    EBox::GConfModule::TestStub::fake( @{ $params{GConfModule} } );
    EBox::Global::TestStub::fake( @{ $params{Global} } );
    EBox::NetWrappers::TestStub::fake( @{ $params{NetWrappers} } );
}


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


sub setConfig
{
  return EBox::GConfModule::TestStub::setConfig(@_); 
}

sub setEBoxModule
{
  return EBox::Global::TestStub::setEBoxModule(@_);
}

sub setEBoxConfigKeys
{
  return EBox::Config::TestStub::setConfigKeys(@_);
}


1;
