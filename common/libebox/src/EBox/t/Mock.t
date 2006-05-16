# Description:
# 
use strict;
use warnings;
#use Smart::Comments; # turn on for debug purposes

use Test::More tests => 7; 
use Test::Exception;
use Test::Output;

use lib '../..';

BEGIN { use_ok 'EBox::Mock' };
mockTest();

sub mockTest
{
    my $debugMsg = "el macaco se desparasita";

    stderr_unlike {
	dies_ok { EBox::debug($debugMsg)  } 'This must fail because the log file is not  writable by ordinary users'; 
    } qr/$debugMsg/, 'Checking that debug text is not printed';
    
    
    EBox::Mock::mock();
    stderr_like {
	lives_ok { EBox::debug($debugMsg)  } 'After mocking any user can use the ebox logger without raising exception';
    } qr/$debugMsg/, 'Checking that debug text is printed in stderr';

    EBox::Mock::unmock();
    stderr_unlike {
	dies_ok { EBox::debug($debugMsg)  } 'After unmocking we get the same behaviour than before';    } qr/$debugMsg/, 'Checking that debug text is not printed like before';
}

1;
