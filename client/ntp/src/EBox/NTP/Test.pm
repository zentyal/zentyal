package EBox::NTP::Test;
# Description:
#
use strict;
use warnings;

use base 'EBox::Test::Class';
use Test::More;

use lib '../..';

sub useTest : Test(1)
{
    use_ok 'EBox::NTP';
}

1;
