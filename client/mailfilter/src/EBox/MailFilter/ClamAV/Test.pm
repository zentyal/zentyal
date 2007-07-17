package EBox::MailFilter::ClamAV::Test;
# package:
use strict;
use warnings;

use base 'EBox::Test::Class';

use EBox::Test;
use Test::File;
use Test::More;
use Test::Exception;
use Perl6::Junction qw(any);

use lib '../../..';
use EBox::MailFilter;

sub setUpTestDir : Test(setup)
{
  my ($self) = @_;
  my $dir = $self->testDir();

  system "rm -rf $dir";
  mkdir $dir;
}



sub setUpConfiguration : Test(setup)
{
    my ($self) = @_;

    my @config = (
		  '/ebox/modules/mailfilter/clamav/active' => 1,
		  '/ebox/modules/mailfilter/clamav/conf_dir' => $self->testDir(),

		  '/ebox/modules/mailfilter/spamassassin/active' => 0,
		  '/ebox/modules/mailfilter/file_filter/holder' => 1,
		  );

    EBox::GConfModule::TestStub::setConfig(@config);
    EBox::Global::TestStub::setEBoxModule('mailfilter' => 'EBox::MailFilter');

    EBox::Config::TestStub::setConfigKeys('tmp' => '/tmp');
}


sub clearConfiguration : Test(teardown)
{
    EBox::GConfModule::TestStub::setConfig();
}


sub testDir 
{
  return '/tmp/ebox.mailfilter.clamav.test';
}


sub writeConfTest #: Test(3)
{
  my ($self) = @_;

  my $clamav = _clamavInstance();

  lives_ok { $clamav->writeConf()  } 'Trying to write configuration files';

  my @files = map  {  $clamav->_clamConfDir() . "/$_" } qw(clamd.conf freshclam.conf );
  foreach (@files) {
    file_not_empty_ok($_. "Checking wether $_ was written");
  }

}


sub freshclamEventTest : Test(14)
{
  my ($self) = @_;

  my $stateFile  = $self->testDir() . '/freshclam.state';
  system "rm -f $stateFile";
  $self->_fakeFreshclamStateFile($stateFile);

  my $clam = _clamavInstance();

  # deviant test
  dies_ok { $clam->notifyFreshclamEvent('unknownState')  } 'Bad event call';

  # first time test
  my $state_r = $clam->freshclamState();
  is_deeply($state_r, { date => undef, update => undef, error => undef, outdated => undef,  }, 'Checking freshclamState when no update has been done');
  
  my @allFields     = qw(update error outdated);
  my @straightCases = ( 
		       # { params => [], activeFields => [] }
		       {
			params         => [ 'update'],
			activeFields   => ['update', 'date'],
		       },
		       {
			params => ['error'],
			activeFields => ['error', 'date'],
		       },
		       {
			params => ['outdated', '0.9a'],
			activeFields => ['outdated', 'date'],
		       }
		      );

  foreach my $case_r (@straightCases) {

    my @params = @{ $case_r->{params} };
    lives_ok { $clam->notifyFreshclamEvent(@params)  } "Calling to freshclamEvent with params @params";

    my $freshclamState = $clam->freshclamState();

    my $anyActiveField = any ( @{ $case_r->{activeFields} });
    foreach my $field (@allFields) {
      if ($field eq $anyActiveField) {
	like $freshclamState->{$field}, qr/[\d\w]+/, "Checking wether active field '$field' has a timestamp value or a version value";
      }
      else {
	is $freshclamState->{$field}, 0, "Checking the value of a inactive state field '$field'"
      }
    }
    
  }
}

sub _fakeFreshclamStateFile
{
  my ($self, $file) = @_;

  Test::MockObject->fake_module('EBox::MailFilter::ClamAV',
				freshclamStateFile => sub { return $file  },
			       );

}


sub _clamavInstance
{
  my $mailfilter = EBox::Global->modInstance('mailfilter');
  return $mailfilter->antivirus();
}

1;
