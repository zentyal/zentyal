#!/usr/bin/perl

# Very simple benchmark script to show how slow Readonly.pm is,
# and how Readonly::XS solves the problem.

use strict;
use Readonly;
use Benchmark;

use vars qw/$feedme/;

#
# use constant
#
use constant CONST_LINCOLN => 'Fourscore and seven years ago...';
sub const
{
    $feedme = CONST_LINCOLN;
}

#
# literal constant
#
sub literal
{
    $feedme = 'Fourscore and seven years ago...';
}

#
# typeglob constant
#
use vars qw/$glob_lincoln/;
*glob_lincoln = \ 'Fourscore and seven years ago...';
sub tglob
{
    $feedme = $glob_lincoln;
}

#
# Normal perl read/write scalar
#
use vars qw/$norm_lincoln/;
$norm_lincoln = 'Fourscore and seven years ago...';
sub normal
{
    $feedme = $norm_lincoln;
}

#
# Readonly.pm with Readonly::XS
#
use vars qw/$roxs_lincoln/;
Readonly::Scalar $roxs_lincoln => 'Fourscore and seven years ago...';
sub roxs
{
    $feedme = $roxs_lincoln;
}

#
# Readonly.pm w/o Readonly::XS
#
use vars qw/$ro_lincoln/;
{
    local $Readonly::XSokay = 0;    # disable XS
    Readonly::Scalar $ro_lincoln => 'Fourscore and seven years ago...';
}
sub ro
{
    $feedme = $ro_lincoln;
}


my $code =
{
 const => \&const,
 literal => \&literal,
 tglob => \&tglob,
 normal => \&normal,
 roxs => \&roxs,
 ro => \&ro,
};

unless ($Readonly::XSokay)
{
    print "Readonly::XS module not found; skipping that test.\n";
    delete $code->{roxs};
}

timethese(2_000_000, $code);
