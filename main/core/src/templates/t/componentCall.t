use strict;
use warnings;

use EBox::Test::Mason;
use Test::More tests => 3;
use Dir::Self;

my $compRoot = __DIR__ . '/..';
my $component = $compRoot . '/componentCall.mas';
my @cases  = (
              [ ],
              [ 'msg.mas', msg => 'single call to msg.mas' ],
              [
               ['msg.mas', msg => 'Multiple calls: first call to msg.mas'],
               ['msg.mas', msg => 'Multiple calls: second call to msg.mas'],
              ],
);

EBox::Test::Mason::testComponent($component, \@cases, compRoot => $compRoot);

1;
