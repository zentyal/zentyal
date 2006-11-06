# $Id: owner.t,v 1.2 2006/03/08 18:34:08 comdog Exp $
use strict;

use Test::Builder::Tester;
use Test::More;
use Test::File;

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#let's test with the first file we find in the current dir
my( $filename, $file_gid, $owner_uid, $owner_name, $file_group_name );
eval 	
	{
	$filename = glob( "*" );
	#print STDERR "Filename is $filename\n";
	
	die "Could not find a file" unless defined $filename;

	$owner_uid = ( stat $filename )[4];
	die "failed to find $filename's owner\n" unless defined $owner_uid;

	$file_gid = ( stat $filename )[5];
	die "failed to find $filename's owner\n" unless defined $file_gid;
		
	$owner_name = ( getpwuid $owner_uid )[0];
	die "failed to find $filename's owner as name\n" unless defined $owner_name;

	$file_group_name = ( getgrgid $file_gid )[0];
	die "failed to find $filename's group as name\n" unless defined $file_group_name;
	};
plan skip_all => "I can't find a file to test with: $@" if $@;

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# find some name that isn't the one we found before
my( $other_name, $other_uid, $other_group_name, $other_gid );
eval 
	{
	for( my $i = 0; $i < 65535; $i++ )	
		{
		next if $i == $owner_uid;	

		my @stats = getpwuid $i;
		next unless @stats;

		( $other_uid, $other_name )  = ( $i, $stats[0] );
		last;
		}
 
 	# XXX: why the for loop?
	for( my $i = 0; $i < 65535; $i++ ) 
		{
		next if $i == $file_gid;	

		my @stats = getgrgid $i;
		next unless @stats;

		( $other_gid, $other_group_name )  = ( $i, $stats[0] );
 		last;
 		}
		
	die "Failed to find another uid" unless defined $other_uid;
	die "Failed to find name for other uid ($other_uid)" 
		unless defined $other_name;
	die "Failed to find another gid" unless defined $other_gid;
	die "Failed to find name for other gid ($other_gid)" 
		unless defined $other_group_name;
	};
plan skip_all => "I can't find a second user id to test with: $@" if $@;

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
plan tests => 12;

owner_is(   $filename, $owner_name, 'owner_is with text username'   );
owner_is(   $filename, $owner_uid,  'owner_is with numeric UID'     );
owner_isnt( $filename, $other_name, 'owner_isnt with text username' );
owner_isnt( $filename, $other_uid,  'owner_isnt with numeric UID'   );

group_is(   $filename, $file_group_name, 'group_is with text groupname'    );
group_is(   $filename, $file_gid,  'group_is with numeric GID'             );
group_isnt( $filename, $other_group_name, 'group_isnt with text groupname' );
group_isnt( $filename, $other_gid,  'group_isnt with numeric GID'          );

my $name = 'Intentional owner_is failure';
test_out( "not ok 1 - $name");
test_diag( 
	"File [$filename] belongs to $owner_name ($owner_uid), not $other_name " .
	"($other_uid)\n" .
	"#   Failed test '$name'\n". 
	"#   in t/owner.t at line " . line_num(+6) . "." 
	);
owner_is( $filename, $other_name, $name );
test_test( $name );

$name = 'Intentional owner_isnt failure';

test_out( "not ok 1 - $name");
test_diag( 
	"File [$filename] belongs to $owner_name ($owner_uid)\n" .
	"#   Failed test '$name'\n" . 
	"#   in t/owner.t at line " . line_num(+5) . "."
	);
owner_isnt( $filename, $owner_name, "Intentional owner_isnt failure" );
test_test( "Intentional owner_isnt failure");

$name = 'Intentional group_is failure';
test_out( "not ok 1 - $name");
test_diag( 
	"File [$filename] belongs to $file_group_name ($file_gid), not ".
	"$other_group_name " .
	"($other_gid)\n" .
	"#   Failed test '$name'\n". 
	"#   in t/owner.t at line " . line_num(+7) . "." 
	);
group_is( $filename, $other_group_name, $name );
test_test( $name );

$name = 'Intentional group_isnt failure';

test_out( "not ok 1 - $name");
test_diag( 
	"File [$filename] belongs to $file_group_name ($file_gid)\n" .
	"#   Failed test '$name'\n" . 
	"#   in t/owner.t at line " . line_num(+5) . "."
	);
group_isnt( $filename, $file_group_name, $name );
test_test( $name );

