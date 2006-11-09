use Test::Tester;

use Test::More qw(no_plan);

use Test::NoWarnings;

use Test::Deep;

Test::Deep::builder(Test::Tester::capture());

1;
