package EBox::MailFilter::SpamAssassin::Test;
# package:
use strict;
use warnings;

use base 'EBox::Test::Class';

use EBox::Test;
use Test::File;
use Test::More;
use Test::Exception;
use Test::MockObject;
use Perl6::Junction qw(any);

use lib '../../..';
use EBox::MailFilter;
use EBox::MailFilter::VDomainsLdap;

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
		  '/ebox/modules/mailfilter/spamassassin/active' => 1,
		  '/ebox/modules/mailfilter/spamassassin/spam_threshold' => 6,
		  '/ebox/modules/mailfilter/spamassassin/autolearn_spam_threshold' => 10,
		  '/ebox/modules/mailfilter/spamassassin/autolearn_ham_threshold' => 2,
#		  '/ebox/modules/mailfilter/spamassassin/conf_dir' => $self->testDir(),

		  '/ebox/modules/mailfilter/clamav/active' => 0,
		  '/ebox/modules/mailfilter/file_filter/holder' => 1,
		  );

    EBox::GConfModule::TestStub::setConfig(@config);
    EBox::Global::TestStub::setEBoxModule('mailfilter' => 'EBox::MailFilter');

 #   EBox::Config::TestStub::setConfigKeys('tmp' => '/tmp');
}


sub clearConfiguration : Test(teardown)
{
    EBox::GConfModule::TestStub::setConfig();
}


sub testDir 
{
  return '/tmp/ebox.mailfilter.spamassassin.test';
}


sub _instanceTest : Test(2)
{
  my $sa;
  lives_ok { 
    my $mailfilter = EBox::Global->modInstance('mailfilter');
    $sa = $mailfilter->antispam();
  } 'Creating an antispam object instance';

  isa_ok($sa, 'EBox::MailFilter::SpamAssassin');
}



sub _saInstance
{
  my $mailfilter = EBox::Global->modInstance('mailfilter');
  return $mailfilter->antispam();
}


sub testThresholds : Test(15)
{

  my $spamThreshold        = 5;
  my $vdomainSpamThreshold = $spamThreshold + 2;
  my $spamAutolearnThreshold = $vdomainSpamThreshold + 3;
  my $hamAutolearnThreshold  = $spamThreshold - 3;

  my %vdomains = (
		  vdomainDefaults => {},
		  vdomainSpamLevel => { spamThreshold => $vdomainSpamThreshold },
		 );
  _fakeVDomains();
  _setFakeVDomains(%vdomains);

  my $mailfilter = EBox::Global->modInstance('mailfilter');
  my $sa = $mailfilter->antispam();


  lives_ok {$sa->setAutolearn(1)  } ' Activate autolearning';

  dies_ok { $sa->setSpamThreshold(-1) } 'Trying to set a negative spam threshold';

  lives_ok  { $sa->setSpamThreshold($spamThreshold)  } ' Setting spam threshold';

  dies_ok {
    $sa->setAutolearnHamThreshold(10)
  } "bad autolearn threshold: ham's level greater than spam's";
  dies_ok {
    $sa->setAutolearnHamThreshold(9);
  } "bad autolearn threshold: ham's level equal than spam's";    
  dies_ok {
    $sa->setAutolearnSpamThreshold(5.864);
  } "bad autolearn threshold: spam's level below the minimum";    
  dies_ok {
    $sa->setAutolearnHamThreshold($spamThreshold);
  } "bad autolearn threshold: ham's level equal than default spam threshold";   
  dies_ok {
    $sa->setAutolearnSpamThreshold( $spamThreshold );
  } "bad autolearn threshold: spam's level equal than one of the vdomains spam threshold";   
    

  lives_ok {
    $sa->setAutolearnSpamThreshold( $spamAutolearnThreshold );
    $sa->setAutolearnHamThreshold( $hamAutolearnThreshold,);
  } "Setting correctly autolearn threshold values";   

  
  dies_ok {
    $sa->setSpamThreshold($hamAutolearnThreshold)
  } "bad default spam threshold level: lesser or equal than ham's autolearn value";
  dies_ok {
    $sa->setSpamThreshold($spamAutolearnThreshold + 0.1)
  } "bad default spam threshold level: greather than spam's autolearn value";
  lives_ok {
    $sa->setSpamThreshold($hamAutolearnThreshold + 1);
  } 'setting default spam threshold to a value between ham and spam autolearn thresholds';

  my $vdomain = 'vdomainSpamLevel';
  dies_ok {
    $sa->setVDomainSpamThreshold($vdomain, $hamAutolearnThreshold)
  } "bad vdomain spam threshold level: lesser or equal than ham's autolearn value";
  dies_ok {
    $sa->setVDomainSpamThreshold($vdomain, $spamAutolearnThreshold + 0.1)
  } "bad vdomain spam threshold level: greather than spam's autolearn value";
  lives_ok {
    $sa->setVDomainSpamThreshold($vdomain, $hamAutolearnThreshold + 1);
  } 'setting default spam threshold to a value between ham and spam autolearn thresholds';
 

}


FAKE_VDOMAIN:{

  sub _fakeVDomains
    {
      Test::MockObject->fake_module('EBox::MailFilter::VDomainsLdap',
				    new       => 
				         \&_fakeVDomainsNew,
				    vdomains => 
				         \&_fakeVDomainsVDomains,
				    spamThreshold => 
				         \&_fakeVDomainSpamThreshold,
				    setSpamThreshold => 
				       \&_fakeVDomainSetSpamThreshold,
				   )

      }


  my %fakeVDomains;

  sub _fakeVDomainsNew
    {
      my ($class) = @_;
      my $self = {};
      bless $self, $class;
      return $self;
    }


  sub _setFakeVDomains
    {
      %fakeVDomains = @_;
    }

  sub _fakeVDomainsVDomains
    {
      return keys %fakeVDomains;
    }


  sub _fakeVDomainSpamThreshold
    {
      my ($self, $vdomain) = @_;
      return $fakeVDomains{$vdomain}->{spamThreshold}

    }

  sub _fakeVDomainSetSpamThreshold
    {
      my ($self, $vdomain, $value) = @_;
      $fakeVDomains{$vdomain}->{spamThreshold} = $value;

    }


}

1;
