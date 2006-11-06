# $Id: setup.t,v 1.4 2006/03/15 15:55:51 comdog Exp $
use strict;

use Test::More tests => 5;

unless( -d 'test_files' )
	{
	mkdir 'test_files', 0700 
		or print "bail out! Could not make directory! $!";
	}
	
chdir 'test_files' or print "bail out! Could not change directory! $!";

my @files = qw(
max_file       non_zero_file  not_readable   readable       zero_file
executable     min_file       not_executable not_writeable  writeable
);

foreach my $file ( @files )
	{
	open FH, "> $file";
	close FH;
	}

my $count = chmod 0400, 'readable', 'not_writeable', 'not_executable';
is( $count, 3 ) or print 'bail out! Could not make files readable';

$count = chmod 0200, 'writeable', 'not_readable',
		'zero_file', 'max_file', 'min_file', 'non_zero_file';
is( $count, 6 ) or print 'bail out! Could not make files writeable';

$count = chmod 0100, 'executable';
is( $count, 1 ) or print 'bail out! Could not make files executable';

truncate 'zero_file', 0;
truncate 'max_file', 10;
truncate 'min_file',  0;

{
open FH, '> min_file' or print "bail out! Could not write to min_file: $!";
print FH "x" x 53;
close FH;
}
is( -s 'min_file', 53 );

chdir '..' or print "bail out! Could not change back to original directory: $!";
pass();
