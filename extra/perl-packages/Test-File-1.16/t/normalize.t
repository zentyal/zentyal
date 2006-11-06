# $Id: normalize.t,v 1.1 2005/01/06 23:35:53 comdog Exp $

use Test::More tests => 9;

use File::Spec;

use_ok( 'Test::File' );

{
my $module = 'File::Spec::Unix';
use_ok( $module );
local @File::Spec::ISA = ( $module );

my $file       = '/foo/bar/baz';
my $normalized = Test::File::_normalize( $file );

is( $normalized, $file, "Normalize gives same path for unix" );
}

{
my $module = 'File::Spec::Win32';
use_ok( $module );
local @File::Spec::ISA = ( $module );

my $file       = '/foo/bar/baz';
my $normalized = Test::File::_normalize( $file );

isnt( $normalized, $file, "Normalize gives different path for Win32" );
is(   $normalized, '\foo\bar\baz', "Normalize gives right path for Win32" );
}

{
my $module = 'File::Spec::Mac';
use_ok( $module );
local @File::Spec::ISA = ( $module );

my $file       = '/foo/bar/baz';
my $normalized = Test::File::_normalize( $file );

isnt( $normalized, $file, "Normalize gives different path for Mac" );
is( $normalized, 'foo:bar:baz', "Normalize gives right path for Mac" );
}	