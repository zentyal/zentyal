package EBox::ProgressIndicator::Test;

use strict;
use warnings;

use base 'EBox::Test::Class';



use Test::Exception;
use Test::More;
use Test::MockObject;

use lib '../..';
use EBox::TestStubs;
use EBox::ProgressIndicator;

sub _fakeModules : Test(startup)
{
  EBox::TestStubs::fakeEBoxModule(
				  name => 'apache',
				  class => 'EBox::Apache',
				 );
  Test::MockObject->fake_module(
				'EBox::ProgressIndicator',
				 _fork => sub {   },
				 );
}

sub creationAndRetrieveTest : Test(5)
{
  my $progress;
  lives_ok {
    $progress = EBox::ProgressIndicator->create(
						totalTicks => 4,
						executable => '/bin/ls',
					       );
  } 'creating progress indicator';

  my $id = $progress->id;
  my $progress2;
  lives_ok {
    $progress2 = EBox::ProgressIndicator->retrieve($id);
  } 'retrieve the same progress indicator';

  my %progressAttrs;
  my %progress2Attrs;
  foreach (qw(id ticks totalTicks started _executable)) {
    $progressAttrs{$_} = $progress->$_;
    $progress2Attrs{$_} = $progress2->$_;
  }

  is_deeply \%progressAttrs, \%progress2Attrs, 'Checking that the two objects are equivalent';

  lives_ok   {  $progress->destroy() } 'destroy progress indicator';
  dies_ok    {  EBox::ProgressIndicator->retrieve($id); } 'checking we cannot retreive a destroyed progress indicator';

}



sub basicUseCaseTest : Test(13)
{

  my $totalTicks = 4;
  my $progress = EBox::ProgressIndicator->create(
						     totalTicks => $totalTicks,
						     executable => '/bin/ls',
					       );

  ok (not $progress->started), 'Checking started propierty after creation of the indicator';
  ok (not $progress->finished), 'Checking finished propierty after creation of the indicator';
  lives_ok {
    $progress->runExecutable();
  } 'run executable';

  ok $progress->started, 'Checking started propierty after runExecutable';
  ok (not $progress->finished), 'Checking finished propierty after runExecutable';


  my $i = 1;
  while ($i <= $totalTicks) {
    $progress->notifyTick();
    is $progress->ticks(), $i, 'checking tick count';
    $i++;
  }

  ok $progress->started, 'Checking started propierty after notify all the ticks';
  ok (not $progress->finished), 'Checking finished propierty after notify all the ticks';


  $progress->setAsFinished();

  ok $progress->finished(), 'checking wether object is marked as finished after marked as finished';  
  ok $progress->started, 'Checking started propierty after object is marked as finished';
}

1;
