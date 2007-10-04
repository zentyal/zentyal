package EBox::MailFilter::Test;
# package:
use strict;
use warnings;

use base 'EBox::Test::Class';

use EBox::Test;

use Perl6::Junction qw(any all);

use Test::Exception;
use Test::More;

use lib '../..';


sub setUpConfiguration : Test(setup)
{
    my ($self) = @_;

    my @config = (
		  '/ebox/modules/mailfilter/clamav/active' => 1,
		  '/ebox/modules/mailfilter/spamassassin/active' => 1,
		  '/ebox/modules/mailfilter/file_filter/holder' => 1,
		  );

    EBox::GConfModule::TestStub::setConfig(@config);
    EBox::Global::TestStub::setEBoxModule('mailfilter' => 'EBox::MailFilter');
}


sub clearConfiguration : Test(teardown)
{
    EBox::GConfModule::TestStub::setConfig();
}

sub _moduleInstantiationTest : Test
{
    EBox::Test::checkModuleInstantiation('mailfilter', 'EBox::MailFilter');
}



sub externalMailDomainTest : Test(21)
{
  my $mf = EBox::MailFilter->_create();

  my @validDomains = qw(
         monos.org
         example.com
         simios.primates.net
    );

  my @invalidDomains = qw (
        invalid/domain
    );


  foreach my $domain (@validDomains) {
    lives_ok {
      $mf->addExternalDomain($domain)
    } "adding external mail domain $domain";

    my $anyExternalDomain = any @{  $mf->externalDomains };
    ok $domain eq $anyExternalDomain, "checking wether domain $domain is in the external domains list";
  }
  
  my @actualExternalDomains = @{  $mf->externalDomains };
  is_deeply [sort @actualExternalDomains], [sort @validDomains], 'checking wether the domain list after the addittions is the expected';


  foreach my $domain (@invalidDomains) {
    dies_ok {
      $mf->addExternalDomain($domain)
    } "checking wether error occurs when adding invalid external mail domain $domain";

    my $allExternalDomain = all @{  $mf->externalDomains };
    ok $domain ne $allExternalDomain, "checking wether invalid domain $domain has not been added to the domain list";
  }
  
  @actualExternalDomains = @{  $mf->externalDomains };
  is_deeply [sort @actualExternalDomains], [sort @validDomains], 'checking wether the domain list after the attempsts of invalid addittions is left untouched';


  dies_ok {
    $mf->removeExternalDomain('inexistent.com')
  } 'checking wether removal of inexistent element raises error';
  
  foreach my $domain (@validDomains) {
    lives_ok {
      $mf->removeExternalDomain($domain)
    } "checking wether error occurs whether external domain $domain can be removed";

    my $allExternalDomain = all @{  $mf->externalDomains };
    ok $domain ne $allExternalDomain, "checking wether removed domain does not appear again in the domain list";

    dies_ok {
      $mf->removeExternalDomain($domain)
    } 'checking wether error occurs wehn trying to remove for second time an element';
  }

  @actualExternalDomains = @{  $mf->externalDomains };
  is_deeply \@actualExternalDomains, [], 'checking wether the list is empty after the removals';

}



1;
