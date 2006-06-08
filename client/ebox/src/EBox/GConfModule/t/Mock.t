# Description:
# 
use strict;
use warnings;

use Test::More tests => 137;
use Test::Exception;
use Test::Deep qw(cmp_bag cmp_deeply);
use File::Basename;

use lib '../../..';

use EBox::Mock;

BEGIN { use_ok 'EBox::GConfModule::Mock' }
mock();
createTest();
setAndGetTest();
setAndGetListTest();
dirExistsTest();
allEntriesTest();
allDirsTest();
deleteDirTest();

sub createTest
{
    my $gconfModule;

    lives_ok {$gconfModule = EBox::GConfModule::_create('EBox::Mandrill', name => 'mandrill') };
    isa_ok ($gconfModule, 'EBox::GConfModule');
}


sub setAndGetTest
{
    my @gettersNames = qw(get_int get_bool get_string );
    my @settersNames = qw(set_int set_bool set_string );

    my $gconfModule = EBox::GConfModule::_create('EBox::Mandrill', name => 'mandrill');

    can_ok($gconfModule, @gettersNames);
    can_ok($gconfModule, @settersNames);

    my @setters = map { $gconfModule->can($_) }  @settersNames;
    my @getters = map { $gconfModule->can($_) }  @gettersNames;

    
    _setAndGetStraightCasesTest($gconfModule, getters => \@getters, setters => \@setters);

}

sub _setAndGetStraightCasesTest
{
    my ($gconfModule, %params) = @_;
    my @getters = @{ $params{getters}  };
    my @setters = @{ $params{setters}  };


    # straight cases...
    # remember that currently the set/get mocks had not type check...
    # so we can set/get any scalar regrdless of gconf type...
    my @keys =  qw(colmillos pelaje/parasitos);
    my @values = (0, 24, 'ea');

    foreach my $getter_r (@getters) {
	foreach my $key (@keys) {	
	    my $actualValue = $getter_r->($gconfModule, $key);
	    ok !defined $actualValue, 'Checking that no existent keys return undef value';
	}
    }

    foreach my $getter_r (@getters) {
	foreach my $setter_r (@setters) {
	    foreach my $key (@keys) {
		foreach my $value (@values) {
		    $setter_r->($gconfModule, $key, $value);
		    my $actualValue = $getter_r->($gconfModule, $key);
		    is $actualValue, $value, "setter and getter of gconf simple type";
		}
	    }

	    last; # it is pointless to continue te loop, whith tests of pairs of get and set fot the same type we are fine for now 
	}
    }

    foreach my $key (@keys) {	
	$gconfModule->unset($key);
	foreach my $getter_r (@getters) {
	    my $actualValue = $getter_r->($gconfModule, $key);
	    ok !defined $actualValue, 'unset';
	}
    }

}

sub setAndGetListTest
{
    my $gconfModule = EBox::GConfModule::_create('EBox::Mandrill', name => 'mandrill');
    my $key = "lista";
    my @lists = (
		 [1],
		 [1, 3, "ea"],
		 [],
	 );

    foreach my $list_r (@lists) {
	$gconfModule->set_list($key, "Ignored parameter for now",  $list_r);
	my $actualValue_r = $gconfModule->get_list($key);

	cmp_deeply $actualValue_r, $list_r, "set_list and get_list";
    }

    $gconfModule->unset($key);
    my $actualValue_r = $gconfModule->get_list($key);
    cmp_deeply $actualValue_r, [], 'Checking unseting of lists';
}


sub dirExistsTest
{
    my $gconfModule = EBox::GConfModule::_create('EBox::Mandrill', name => 'mandrill');
    
    $gconfModule->set_string('groomingPartners/coco' => 'toBeGroomed');
    ok $gconfModule->dir_exists('groomingPartners'), 'dir_exists';
    ok !$gconfModule->dir_exists('groomingPartners/coco'), 'dir_exists';

    $gconfModule->set_bool ('banana' => 1)  ;
    ok !$gconfModule->dir_exists('banana'), 'dir_exists';

    # inexistent entry..
      ok !$gconfModule->dir_exists('suits'), 'dir_exists';
	
}

sub allEntriesTest
{
    _setFakeConfig();
    my $gconfModule = EBox::GConfModule::_create('EBox::Mandrill', name => 'mandrill');

    my %cases = (
		  #dir entries
		 'grooming_partners' =>[qw(grooming_partners/koko grooming_partners/ebo)],                 'foodEaten'         => [],
		 'foodEaten/prey'    => [qw(foodEaten/prey/rats)],
		 'foodEaten/prey/insects'    => [qw(foodEaten/prey/insects/ants foodEaten/prey/insects/beatles)],
		 'foodEaten/plants'    => [qw(foodEaten/plants/bananas foodEaten/plants/seeds)],
		  # module's homedir in absolute path
		  '/ebox/modules/mandrill'   => [qw(status)],
		  # module's homedir in realitive path
                  ''                         => [qw(status)],
		  # not dir entries
		 'grooming_partners/koko' => [],
		 'status'                 => [],

		 # inexistent dir 
		 'cars'   => [],
		 # inexistent dir that exist in anothe module
		 'trees'  => [],

	      );

    while (my ($key, $awaitedResult) = each %cases ) {
	my @actualResult = $gconfModule->all_entries($key);
	my @nReferences = grep { ref $_ } @actualResult;
	is @nReferences, 0, 'Checking that result is a flat list';
	cmp_bag \@actualResult, $awaitedResult, "all_entries($key)";
    }

    while (my ($key, $resultWithPath) = each %cases ) {
	my @awaitedResult = map { basename $_ }  @{ $resultWithPath };
	my $actualResult = $gconfModule->all_entries_base($key);
	is ref $actualResult, "ARRAY", "Checking that he result is a reference to a array";
	cmp_bag $actualResult, \@awaitedResult, "all_entries_base($key)";
    }
}

sub allDirsTest
{
    _setFakeConfig();
    my $gconfModule = EBox::GConfModule::_create('EBox::Mandrill', name => 'mandrill');

    my %cases = (
		  #dir entries
		 'grooming_partners' => [],
                  'foodEaten'         => [qw(foodEaten/prey foodEaten/plants) ],
		 'foodEaten/prey'    => [qw(foodEaten/prey/insects)],
		 'foodEaten/prey/insects'    => [],
		 'foodEaten/plants'   => [],

		  # module's homedir in absolute path
		  '/ebox/modules/mandrill'   => [qw(grooming_partners foodEaten)],
		  # module's homedir in realitive path
                  ''                         => [qw(grooming_partners foodEaten)],

		  # not dir entries
		 'grooming_partners/koko' => [],
		 'status'                 => [],

		 # inexistent dir 
		 'cars'   => [],
		 # inexistent dir that exists in anothe module
		 'trees'  => [],
	      );

   while (my ($key, $awaitedResult) = each %cases ) {
	my @actualResult = $gconfModule->all_dirs($key);
	my @nReferences = grep { ref $_ } @actualResult;
	is @nReferences, 0, 'Checking that result is a flat list';
	cmp_bag \@actualResult, $awaitedResult, "all_dirs($key)";
    }

    while (my ($key, $resultWithPath) = each %cases ) {
	my @awaitedResult = map { basename $_ }  @{ $resultWithPath };
	my $actualResult = $gconfModule->all_dirs_base($key);
	is ref $actualResult, "ARRAY", "Checking that he result is a reference to a array";
	cmp_bag $actualResult, \@awaitedResult, "all_dirs_base($key)";
    }
}


sub deleteDirTest
{
    _setFakeConfig();
    my $gconfModule = EBox::GConfModule::_create('EBox::Mandrill', name => 'mandrill');

    # try with a simple dir, a subdir and a dir with nested dirs..
    foreach my $dir ('grooming_partners', 'foodEaten/prey/insects', 'foodEaten') {
	$gconfModule->dir_exists($dir) or die "Fake config incorrectly stted";
	lives_ok { $gconfModule->delete_dir($dir) } "Checking removal fake of gconf dir $dir";
	$gconfModule->dir_exists($dir) and die "It exists..";
	ok !$gconfModule->dir_exists($dir), "Testing that  dir $dir was deleted";
    }
}

sub _setFakeConfig
{
   my @config = (
		  '/ebox/modules/mandrill/grooming_partners/koko' => 'groomed today',
		  '/ebox/modules/mandrill/grooming_partners/ebo'  =>  'groomed me yesterday',
		  '/ebox/modules/mandrill/status'                 => 'alpha',
		  '/ebox/modules/mandrill/foodEaten/prey/insects/ants'     =>  3,
		  '/ebox/modules/mandrill/foodEaten/prey/insects/beatles'  =>  4,
		  '/ebox/modules/mandrill/foodEaten/prey/rats'             =>  0,
		  '/ebox/modules/mandrill/foodEaten/plants/bananas'        =>  10,
		  '/ebox/modules/mandrill/foodEaten/plants/seeds'          =>  23,
		 
		  '/ebox/modules/forest/trees/pine'                         =>  14, 
	      );

   EBox::GConfModule::Mock::setConfig(@config);

}



sub mock
{
    EBox::GConfModule::Mock::mock();
      EBox::Mock::mock();
}


# dummy class for testing
package EBox::Mandrill;
use base 'EBox::GConfModule';
$INC{'EBox/Mandrill.pm'} = 1;


1;
