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
