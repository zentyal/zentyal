use strict;
use warnings;

use Test::More tests => 6;
use Test::Exception;
use Test::Output;

use lib '../..';
use EBox;
use EBox::TestStub;

mockTest();

sub mockTest
{
    my $debugMsg = "el macaco se desparasita";

    stderr_like {
            EBox::info($debugMsg)
    } qr/Trace begun at.*EBox/, 'This must print a stderr trace because the logger cannot be intialized by a regular user';


    EBox::TestStub::fake();

    stderr_like {
        lives_ok {
            EBox::info($debugMsg)
        } 'After mocking any user can use the ebox logger normally';
   } qr/$debugMsg/, 'Checking that debug text is printed in stderr';

    stderr_like {
        lives_ok {
            EBox::info($debugMsg)
        } 'Checking that after the first initializtion the behaviour is unchanged';
    } qr/$debugMsg/, 'Checking log text';

     EBox::TestStub::unfake();
    stderr_like {
        EBox::info($debugMsg)
      } qr/Trace begun at.*EBox/, 'After unmocking we get the same behaviour than before';
}

1;
