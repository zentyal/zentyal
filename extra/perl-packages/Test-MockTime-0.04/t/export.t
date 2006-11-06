use strict;
use warnings;
use Test::More tests => 1;
use Test::MockTime qw( :all );

eval{
    set_relative_time(1);
    set_absolute_time(2);
    set_fixed_time(3);
    restore_time;
};
is( $@, q{}, ':all export tag works' );
