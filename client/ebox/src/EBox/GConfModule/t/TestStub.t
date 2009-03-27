# Description:
# 
use strict;
use warnings;

#use Test::More tests => 151;
use Test::More qw(no_plan);
use Test::Exception;
use Test::Deep qw(cmp_bag cmp_deeply);
use File::Basename;

use lib '../../..';

use EBox::TestStub;

BEGIN { use_ok 'EBox::GConfModule::TestStub' }
mock();
createTest();
setAndGetTest();
setAndGetListTest();
# dirExistsTest();
# allEntriesTest();
# allDirsTest();
# hashFromDirTest();
# deleteDirTest();
unfakeTest();

sub createTest
{
    my $gconfModule;

    lives_ok {$gconfModule = EBox::GConfModule::_create('EBox::Mandrill', name => 'mandrill') };
    isa_ok ($gconfModule, 'EBox::GConfModule');
}


sub setAndGetTest
{
    my $gconfModule = EBox::GConfModule::_create('EBox::Mandrill', name => 'mandrill');

   my @cases =(
               {
                   getter => 'get_int',
                   setter => 'set_int',
                   values => [0, 12, -21],
                   unsetValue => 0,
               },
               {
                   getter => 'get_bool',
                   setter => 'set_bool',
                   values => [0, 1, undef],
                   expectedValues => [0, 1, 0],
                   unsetValue => 0,
               },
               {
                   getter => 'get_string',
                   setter => 'set_string',
                   values => ['aaa', ''],
               },
              );

   my @gettersNames = map {
       $_->{getter}
   } @cases;


   my @settersNames = map {
       $_->{setter}
   } @cases;

    can_ok($gconfModule, @gettersNames);
    can_ok($gconfModule, @settersNames);


    foreach my $case (@cases) {
        _setAndGetStraightCasesTest($gconfModule, $case);
    }
    
}

sub _setAndGetStraightCasesTest
{
    my ($gconfModule, $case) = @_;
    my $getter = $case->{getter};
    my $setter = $case->{setter};
    my @values = @{ $case->{values} };
    my $unsetValue = undef;
    if (exists $case->{unsetValue}) {
        $unsetValue = $case->{unsetValue};
    }
    my @expectedValues;
    if (exists $case->{expectedValues}) {
        @expectedValues = @{ $case->{expectedValues} };
    } else {
        @expectedValues = @values;
    }


    diag "Case for $getter/$setter wirh values @values";

    # straight cases...
    # remember that currently the set/get mocks had not type check...
    # so we can set/get any scalar regrdless of gconf type...
    my @keys =  qw(colmillos pelaje/parasitos);

    foreach my $key (@keys) {       
        my $actualValue = $gconfModule->$getter($key);
        is $actualValue, $unsetValue, "Checking that $getter upon no-existent key $key return unset value";
    }


    foreach my $key (@keys) {
        
        foreach my $nValue (0 .. (@values -1)) {
            my $value = $values[$nValue];
            my $expectedValue = $expectedValues[$nValue];

            $gconfModule->$setter($key, $value);
            my $actualValue = $gconfModule->$getter($key);
#            use Data::Dumper;
#            print "ACTAUL VALUE " . Dumper($actualValue);
             

            is $actualValue, $expectedValue, "
              $setter and $getter test with $value";
        }
    }


    foreach my $key (@keys) {   
        $gconfModule->unset($key);
        my $actualValue = $gconfModule->$getter($key);
        is $actualValue, $unsetValue, 'checking that after usnet keys return unset value';
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


sub hashFromDirTest 
{
    _setFakeConfig();
    my $gconfModule = EBox::GConfModule::_create('EBox::Mandrill', name => 'mandrill');

    my %cases = (
		 # dirs
		 'grooming_partners' => {
					 'koko' => 'groomed today',
					 'ebo'  =>  'groomed me yesterday',
					},
		 
                  'foodEaten'        => {},
		  'foodEaten/prey'   => {
					 'rats'             =>  0,
					},
		  'foodEaten/prey/insects' => {
					       ants => 3,
					       beatles =>  4,
					      },
		 'foodEaten/plants' =>  {
					 'bananas'        =>  10,
					 'seeds'          =>  23,
					},

		 'inexistentDir'          => {},

	      );

    while (my ($dir, $expectedResults_r) = each %cases) {
      my $actualResults_r;
      lives_ok {
	$actualResults_r = $gconfModule->hash_from_dir($dir)
      }  "executing hash_from_dir upon configuration directory $dir";

      is_deeply $actualResults_r, $expectedResults_r, 
	'checking hash_from_dir output';
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

   EBox::GConfModule::TestStub::setConfig(@config);

}



sub mock
{
    EBox::GConfModule::TestStub::fake();
    EBox::TestStub::fake();
}


sub unfakeTest
{
  _setFakeConfig();
  my $gconfModule = EBox::GConfModule::_create('EBox::Mandrill', name => 'mandrill');

  defined $gconfModule->get_string('status') or die 'Error faking module';

  lives_ok {   EBox::GConfModule::TestStub::unfake();  } 'Unfake EBox::GConfModule';


  is $gconfModule->get_string('status'), undef, 'Checking that we cannot longer access to faked gconf data';

}

# dummy class for testing
package EBox::Mandrill;
use base 'EBox::GConfModule';
$INC{'EBox/Mandrill.pm'} = 1;


1;
