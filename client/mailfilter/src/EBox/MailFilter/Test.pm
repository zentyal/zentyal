package EBox::MailFilter::Test;
# package:
use strict;
use warnings;

use base 'EBox::Test::Class';

use EBox::Test;
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



1;
