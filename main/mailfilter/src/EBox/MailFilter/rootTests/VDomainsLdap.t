use strict;
use warnings;

use Test::More skip_all => 'FIXME_roottests';
use Test::More tests => 60;
use Test::Exception;

use EBox;
use EBox::Global;
use EBox::MailVDomainsLdap;
use TryCatch;

diag "This test uses the Zentyal LDAP. Don't use it in production environments!!";

use_ok('EBox::MailFilter::VDomainsLdap');

EBox::init();

my $vdomain = 'testdomain.com';

try {
  _createTestVDomain($vdomain);
  testPrimitives($vdomain);
  testSenderList($vdomain, 'whitelist');
  testSenderList($vdomain, 'blacklist');
  testBoolAttr($vdomain, 'antivirus');
  testBoolAttr($vdomain, 'antispam');
  testFloatAttr($vdomain, 'spamThreshold');
  testReset($vdomain);
} catch ($e) {
  _removeVDomain($vdomain);
  $e->throw();
}
_removeVDomain($vdomain);


sub _createTestVDomain
{
  my ($vdomain) = @_;

  my $mailvdomains = EBox::MailVDomainsLdap->new();


  $mailvdomains->addVDomain($vdomain, 10000);

  lives_ok {
    EBox::MailFilter::VDomainsLdap->new()->_addVDomain($vdomain);
  } 'Trying to create domain';
  my $vdomainExists = EBox::MailVDomainsLdap->new()->vdomainExists($vdomain);
  ok $vdomainExists, 'Checking existence of newly create domain';
}

sub _removeVDomain
{
  my ($vdomain) = @_;

  my $mailvdomains = EBox::MailVDomainsLdap->new();
  lives_ok {
    $mailvdomains->delVDomain($vdomain);
  } 'Trying to delete test domain';
  my $vdomainExists = EBox::MailVDomainsLdap->new()->vdomainExists($vdomain);
  my $vdomainNotExists = not $vdomainExists;
  ok $vdomainNotExists, 'Checking wether domain not longer exists';
}

sub testPrimitives # 3
{
  my ($vdomain) = @_;

  my $mailvdomains = EBox::MailFilter::VDomainsLdap->new();

  can_ok($mailvdomains,
	'_vdomainAttr',
	'_setVDomainAttr');

  my $attr = 'amavisSpamTagLevel';
  lives_ok {  $mailvdomains->_setVDomainAttr($vdomain, $attr, 'ea') } 'Setting TagLevel';
  is $mailvdomains->_vdomainAttr($vdomain, $attr), 'ea', 'Checking tag level';
}

sub testSenderList  # 8 tests
{
  my ($vdomain, $type) = @_;

  my $vdomainsLdap = new EBox::MailFilter::VDomainsLdap;
  my $getter = $type;
  my $setter  = "set\u$type";

  my @cases = (
	       [],
	       ['ea@test.com'],
	       [qw(ea@test.com @foo.bar)],
	       [],
	      );

  foreach my $senderList (@cases) {
    lives_ok {
      $vdomainsLdap->$setter($vdomain, $senderList)
    } "Setting $type list with $setter";
    lives_and ( sub {
		  my $actualList =  [$vdomainsLdap->$getter($vdomain)];
		  is_deeply $actualList, $senderList;
		}, 'Checking wether the list was correctly set');


  }
}

sub testBoolAttr # 10 checks
{
  my ($vdomain, $attr) = @_;
  my $getter = $attr;
  my $setter = "set\u$attr";

  my @cases = (0, 0, 1, 1, 0);
  _testMutator($vdomain, $getter, $setter, @cases);
}

sub testFloatAttr  # 12 checks
{
  my ($vdomain, $attr) = @_;
  my $getter = $attr;
  my $setter = "set\u$attr";


  my @cases = (0, 0.4, -3, 3.3, 4, -3.1);
  _testMutator($vdomain, $getter, $setter, @cases);
}

sub _testMutator
{
  my ($vdomain, $getter, $setter, @cases) = @_;

  my $vdomainsLdap = new EBox::MailFilter::VDomainsLdap;

  foreach my $state (@cases) {
    lives_ok {
      $vdomainsLdap->$setter($vdomain, $state)
    } "Setting state $state";
    lives_and (
	       sub {
		 my $actualState = $vdomainsLdap->$getter($vdomain) ;
		 is $actualState, $state;
	       },
	       'Checking wether the state was correctly set');
  }
}

sub testReset
{
  my ($vdomain) = @_;
  my $vdomainsLdap = new EBox::MailFilter::VDomainsLdap;

  $vdomainsLdap->setAntivirus($vdomain, 1);
  $vdomainsLdap->setAntispam($vdomain, 1);

  lives_ok { $vdomainsLdap->resetVDomain($vdomain) } 'Executing reset method';

  my @attrs = qw(spamThreshold);
  foreach my $attr (@attrs) {
    my $value = $vdomainsLdap->$attr($vdomain);
    is $value, undef, "checking wether attribute $attr was cleared";
  }

  my @boolAttrs = qw ( antivirus antispam);
  foreach my $attr (@boolAttrs) {
    my $value = $vdomainsLdap->$attr($vdomain);
    is $value, 1, "checking wether boolean attribute $attr was cleared to default value (true)";
  }
}

1;
