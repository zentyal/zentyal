#!perl -I..

# Readonly hash tests

use strict;
use Test::More tests => 1;

# Find the module (1 test)
BEGIN {use_ok('Readonly', qw/Scalar Scalar1 Array Array1 Hash Hash1/); }

