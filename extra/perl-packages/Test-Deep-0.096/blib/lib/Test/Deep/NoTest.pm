use strict;
use warnings;

# this is for people who don't want Test::Builder to be loaded but want to
# use eq_deeply. It's a bit hacky...

package Test::Deep::NoTest;

use vars qw( $NoTest @ISA @EXPORT );

require Exporter;
@ISA = qw( Exporter );

@EXPORT = qw(
	eq_deeply useclass noclass set bag subbagof superbagof
	subsetof supersetof superhashof subhashof
);


local $NoTest = 1;
require Test::Deep;
Test::Deep->import( @EXPORT );

1;
