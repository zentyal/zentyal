use strict;
use warnings;

use EBox::Test::Mason;
use Dir::Self;
use Test::More tests => 5;

my $compRoot = __DIR__ . '/..';
my $template =  $compRoot . '/table.mas';
my @columnTitles = qw(arabic roman binary);
my @rows = (
            ['0', 'no symbol for zero', 0,],
            ['4', 'IV', '100',],
            ['15', 'XV', '1111',],
           );
my @additionalComponents = (
                       'msg.mas', msg => "suddenly, a message",
);

my @cases = (
             [],  # no arguments case
             [rows => \@rows ],
             [columnTitles => \@columnTitles],
             [columnTitles => \@columnTitles, rows => \@rows],
             [columnTitles => \@columnTitles, rows => \@rows, additionalComponents => \@additionalComponents],
            );


EBox::Test::Mason::testComponent($template, \@cases, compRoot => $compRoot);

1;
