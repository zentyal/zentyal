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
#
# package: EBox::Test
#
#  Contains specifically-ebox checks and helper.
#
# deprecated:  
#     activateEBoxTestStubs fakeEBoxModule setConfig setConfigKeys
#     this was moved to EBox::TestStub


use Test::More;
use Test::Builder;

use Error qw(:try);
use EBox::TestStubs;
use Params::Validate;

my @deprecatedSubs = qw(activateEBoxTestStubs fakeEBoxModule setConfig setConfigKeys fakeEBoxModule);
our @EXPORT_OK = ('checkModuleInstantiation', @deprecatedSubs);
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
    validate_pos(@_, 1, 1);

    eval  "use  $modulePackage";
    if ($@) {
	$Test->ok(0, "$modulePackage failed to load");
	return;
    }
 
    my $global = EBox::Global->getInstance();
    defined $global or die "Cannot get a instance of the global module";
	
    my $instance;
    my $modInstanceError = 0;

    try {
	$instance = $global->modInstance($moduleName);
    }
    otherwise {
	$modInstanceError = 1;;
    };
    
    if ($modInstanceError or !defined $instance) {
	$Test->ok(0, "Cannot create an instance of the EBox's module $moduleName");
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







# deprecated subs:
sub activateEBoxTestStubs
{
  _deprecated('activateEBoxTestStubs', 'EBox::TestStubs', 'activateTestStubs', @_);
}

sub setEBoxModule
{
  _deprecated('setEBoxModule', 'EBox::TestStubs', 'setEBoxModule', @_);
}

sub setConfig
{
  _deprecated('setConfig', 'EBox::TestStubs', 'setConfig', @_);
}

sub setEBoxConfigKeys
{
  _deprecated('setEBoxConfigKeys', 'EBox::TestStubs', 'setEBoxConfigKeys', @_);
}

sub fakeEBoxModule
{
  _deprecated('fakeEBoxModule', 'EBox::TestStubs', 'fakeEBoxModule', @_);
}

sub _deprecated
{
  my ($subName, $newSubModule, $newSubName, @subParams) = @_;
  
  my $msg = "$subName is deprecated. Use $newSubModule::$newSubName instead";
  warn $msg;
 

  my $sub_r = $newSubModule->can( $newSubName);
  defined $sub_r or die "Cannot found $newSubModule\:\:$newSubName to replace deprecated sub $subName";
  return $sub_r->(@subParams);
}

1;
