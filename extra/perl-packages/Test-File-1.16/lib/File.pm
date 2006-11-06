# $Id: File.pm,v 1.16 2006/07/08 20:37:22 comdog Exp $
package Test::File;
use strict;

use base qw(Exporter);
use vars qw(@EXPORT $VERSION);

use File::Spec;
use Test::Builder;

@EXPORT = qw(
	file_exists_ok file_not_exists_ok
	file_empty_ok file_not_empty_ok file_size_ok file_max_size_ok
	file_min_size_ok file_readable_ok file_not_readable_ok file_writeable_ok
	file_not_writeable_ok file_executable_ok file_not_executable_ok
	file_mode_is file_mode_isnt
	file_is_symlink_ok
	symlink_target_exists_ok
	symlink_target_dangles_ok
	link_count_is_ok link_count_gt_ok link_count_lt_ok
	owner_is owner_isnt
	group_is group_isnt
	);

$VERSION = sprintf "%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/;

my $Test = Test::Builder->new();

=head1 NAME

Test::File -- test file attributes

=head1 SYNOPSIS

use Test::File;

=head1 DESCRIPTION

This modules provides a collection of test utilities for file
attributes.

Some file attributes depend on the owner of the process testing the
file in the same way the file test operators do.  For instance, root
(or super-user or Administrator) may always be able to read files no
matter the permissions.

Some attributes don't make sense outside of Unix, either, so some
tests automatically skip if they think they won't work on the
platform.  If you have a way to make these functions work on Windows,
for instance, please send me a patch. :)

=head2 Functions

=cut

sub _normalize
	{
	my $file = shift;
	return unless defined $file;

	return $file =~ m|/|
		? File::Spec->catfile( split m|/|, $file )
		: $file;
	}

sub _win32
	{
	return 0 if $^O eq 'darwin';
	return $^O =~ m/Win/;
	}

sub _no_symlinks_here { ! eval { symlink("",""); 1 } }

# owner_is and owner_isn't should skip on OS where the question makes no
# sence.  I really don't know a good way to test for that, so I'm going
# to skip on the two OS's that I KNOW aren't multi-user.  I'd love to add
# more if anyone knows of any
#   Note:  I don't have a dos or mac os < 10 machine to test this on
sub _obviously_non_multi_user
	{
	($^O eq 'dos')   ?
		return 1
			:
	($^O eq 'MacOS') ?
		return 1
			:
		return;

	eval { my $holder = getpwuid(0) };
	return 1 if $@;

	eval { my $holder = getgrgid(0) };
	return 1 if $@;

	return 0;
	}

=over 4

=item file_exists_ok( FILENAME [, NAME ] )

Ok if the file exists, and not ok otherwise.

=cut

sub file_exists_ok($;$)
	{
	my $filename = _normalize( shift );
	my $name     = shift || "$filename exists";

	my $ok = -e $filename;

	if( $ok )
		{
		$Test->ok(1, $name);
		}
	else
		{
		$Test->diag("File [$filename] does not exist");
		$Test->ok(0, $name);
		}
	}

=item file_not_exists_ok( FILENAME [, NAME ] )

Ok if the file does not exist, and not okay if it does exist.

=cut

sub file_not_exists_ok($;$)
	{
	my $filename = _normalize( shift );
	my $name     = shift || "$filename does not exist";

	my $ok = not -e $filename;

	if( $ok )
		{
		$Test->ok(1, $name);
		}
	else
		{
		$Test->diag("File [$filename] exists");
		$Test->ok(0, $name);
		}
	}

=item file_empty_ok( FILENAME [, NAME ] )

Ok if the file exists and has empty size, not ok if the
file does not exist or exists with non-zero size.

=cut

sub file_empty_ok($;$)
	{
	my $filename = _normalize( shift );
	my $name     = shift || "$filename is empty";

	my $ok = -z $filename;

	if( $ok )
		{
		$Test->ok(1, $name);
		}
	else
		{
		if( -e $filename )
			{
			my $size = -s $filename;
			$Test->diag( "File exists with non-zero size [$size] b");
			}
		else
			{
			$Test->diag( 'File does not exist');
			}

		$Test->ok(0, $name);
		}
	}

=item file_not_empty_ok( FILENAME [, NAME ] )

Ok if the file exists and has non-zero size, not ok if the
file does not exist or exists with zero size.

=cut

sub file_not_empty_ok($;$)
	{
	my $filename = _normalize( shift );
	my $name     = shift || "$filename is not empty";

	my $ok = not -z $filename;

	if( $ok )
		{
		$Test->ok(1, $name);
		}
	else
		{
		if( -e $filename and -z $filename )
			{
			$Test->diag( "File [$filename] exists with zero size" );
			}
		else
			{
			$Test->diag( "File [$filename] does not exist" );
			}

		$Test->ok(0, $name);
		}
	}

=item file_size_ok( FILENAME, SIZE [, NAME ]  )

Ok if the file exists and has SIZE size in bytes (exactly), not ok if
the file does not exist or exists with size other than SIZE.

=cut

sub file_size_ok($$;$)
	{
	my $filename = _normalize( shift );
	my $expected = int shift;
	my $name     = shift || "$filename has right size";

	my $ok = ( -s $filename ) == $expected;

	if( $ok )
		{
		$Test->ok(1, $name);
		}
	else
		{
		unless( -e $filename )
			{
			$Test->diag( "File [$filename] does not exist" );
			}
		else
			{
			my $actual = -s $filename;
			$Test->diag(
				"File [$filename] has actual size [$actual] not [$expected]" );
			}

		$Test->ok(0, $name);
		}
	}

=item file_max_size_ok( FILENAME, MAX [, NAME ] )

Ok if the file exists and has size less than or equal to MAX bytes, not
ok if the file does not exist or exists with size greater than MAX
bytes.

=cut

sub file_max_size_ok($$;$)
	{
	my $filename = _normalize( shift );
	my $max      = int shift;
	my $name     = shift || "$filename is under $max bytes";

	my $ok = ( -s $filename ) <= $max;

	if( $ok )
		{
		$Test->ok(1, $name);
		}
	else
		{
		unless( -e $filename )
			{
			$Test->diag( "File [$filename] does not exist" );
			}
		else
			{
			my $actual = -s $filename;
			$Test->diag(
				"File [$filename] has actual size [$actual] " .
				"greater than [$max]"
				);
			}

		$Test->ok(0, $name);
		}
	}

=item file_min_size_ok( FILENAME, MIN [, NAME ] )

Ok if the file exists and has size greater than or equal to MIN bytes,
not ok if the file does not exist or exists with size less than MIN
bytes.

=cut

sub file_min_size_ok($$;$)
	{
	my $filename = _normalize( shift );
	my $min      = int shift;
	my $name     = shift || "$filename is over $min bytes";

	my $ok = ( -s $filename ) >= $min;

	if( $ok )
		{
		$Test->ok(1, $name);
		}
	else
		{
		unless( -e $filename )
			{
			$Test->diag( "File [$filename] does not exist" );
			}
		else
			{
			my $actual = -s $filename;
			$Test->diag(
				"File [$filename] has actual size ".
				"[$actual] less than [$min]"
				);
			}

		$Test->ok(0, $name);
		}
	}

=item file_readable_ok( FILENAME [, NAME ] )

Ok if the file exists and is readable, not ok
if the file does not exist or is not readable.

=cut

sub file_readable_ok($;$)
	{
	my $filename = _normalize( shift );
	my $name     = shift || "$filename is readable";

	my $ok = -r $filename;

	if( $ok )
		{
		$Test->ok(1, $name);
		}
	else
		{
		$Test->diag( "File [$filename] is not readable" );
		$Test->ok(0, $name);
		}
	}

=item file_not_readable_ok( FILENAME [, NAME ] )

Ok if the file exists and is not readable, not ok
if the file does not exist or is readable.

=cut

sub file_not_readable_ok($;$)
	{
	my $filename = _normalize( shift );
	my $name     = shift || "$filename is not readable";

	my $ok = not -r $filename;

	if( $ok )
		{
		$Test->ok(1, $name);
		}
	else
		{
		$Test->diag( "File [$filename] is readable" );
		$Test->ok(0, $name);
		}
	}

=item file_writeable_ok( FILENAME [, NAME ] )

Ok if the file exists and is writeable, not ok
if the file does not exist or is not writeable.

=cut

sub file_writeable_ok($;$)
	{
	my $filename = _normalize( shift );
	my $name     = shift || "$filename is writeable";

	my $ok = -w $filename;

	if( $ok )
		{
		$Test->ok(1, $name);
		}
	else
		{
		$Test->diag( "File [$filename] is not writeable" );
		$Test->ok(0, $name);
		}
	}

=item file_not_writeable_ok( FILENAME [, NAME ] )

Ok if the file exists and is not writeable, not ok
if the file does not exist or is writeable.

=cut

sub file_not_writeable_ok($;$)
	{
	my $filename = _normalize( shift );
	my $name     = shift || "$filename is not writeable";

	my $ok = not -w $filename;

	if( $ok )
		{
		$Test->ok(1, $name);
		}
	else
		{
		$Test->diag("File [$filename] is writeable");
		$Test->ok(0, $name);
		}
	}

=item file_executable_ok( FILENAME [, NAME ] )

Ok if the file exists and is executable, not ok
if the file does not exist or is not executable.

This test automatically skips if it thinks it is on a
Windows platform.

=cut

sub file_executable_ok($;$)
	{
    if( _win32() )
		{
		$Test->skip( "file_executable_ok doesn't work on Windows" );
		return;
		}

	my $filename = _normalize( shift );
	my $name     = shift || "$filename is executable";

	my $ok = -x $filename;

	if( $ok )
		{
		$Test->ok(1, $name);
		}
	else
		{
		$Test->diag("File [$filename] is not executable");
		$Test->ok(0, $name);
		}
	}

=item file_not_executable_ok( FILENAME [, NAME ] )

Ok if the file exists and is not executable, not ok
if the file does not exist or is executable.

This test automatically skips if it thinks it is on a
Windows platform.

=cut

sub file_not_executable_ok($;$)
	{
	if( _win32() )
		{
		$Test->skip( "file_not_executable_ok doesn't work on Windows" );
		return;
		}

	my $filename = _normalize( shift );
	my $name     = shift || "$filename is not executable";

	my $ok = not -x $filename;

	if( $ok )
		{
		$Test->ok(1, $name);
		}
	else
		{
		$Test->diag("File [$filename] is executable");
		$Test->ok(0, $name);
		}
	}

=item file_mode_is( FILENAME, MODE [, NAME ] )

Ok if the file exists and the mode matches, not ok
if the file does not exist or the mode does not match.

This test automatically skips if it thinks it is on a
Windows platform.

Contributed by Shawn Sorichetti C<< <ssoriche@coloredblocks.net> >>

=cut

sub file_mode_is($$;$)
	{
    if( _win32() )
		{
		$Test->skip( "file_mode_is doesn't work on Windows" );
		return;
		}

	my $filename = _normalize( shift );
	my $mode     = shift;

	my $name     = shift || sprintf("%s mode is %04o", $filename, $mode);

	my $ok = -e $filename && ((stat($filename))[2] & 07777) == $mode;

	if( $ok )
		{
		$Test->ok(1, $name);
		}
	else
		{
		$Test->diag(sprintf("File [%s] mode is not %04o", $filename, $mode) );
		$Test->ok(0, $name);
		}
	}

=item file_mode_isnt( FILENAME, MODE [, NAME ] )

Ok if the file exists and mode does not match, not ok
if the file does not exist or mode does match.

This test automatically skips if it thinks it is on a
Windows platform.

Contributed by Shawn Sorichetti C<< <ssoriche@coloredblocks.net> >>

=cut

sub file_mode_isnt($$;$)
	{
    if( _win32() )
		{
		$Test->skip( "file_mode_isnt doesn't work on Windows" );
		return;
		}

	my $filename = _normalize( shift );
	my $mode     = shift;

	my $name     = shift || sprintf("%s mode is not %04o",$filename,$mode);

	my $ok = not (-e $filename && ((stat($filename))[2] & 07777) == $mode);

	if( $ok )
		{
		$Test->ok(1, $name);
		}
	else
		{
		$Test->diag(sprintf("File [%s] mode is %04o",$filename,$mode));
		$Test->ok(0, $name);
		}
	}

=item file_is_symlink_ok( FILENAME [, NAME] )

Ok is FILENAME is a symlink, even if it points to a non-existent
file. This test automatically skips if the operating system does
not support symlinks. If the file does not exist, the test fails.

The optional NAME parameter is the name of the test.

=cut

sub file_is_symlink_ok
	{
    if( _no_symlinks_here() )
		{
		$Test->skip(
			"file_is_symlink_ok doesn't work on systems without symlinks" );
		return;
		}

	my $file = shift;
	my $name = shift || "$file is a symlink";

	if( -l $file )
		{
		$Test->ok(1, $name)
		}
	else
		{
		$Test->diag( "File [$file] is not a symlink!" );
		$Test->ok(0, $name);
		}
	}

=item symlink_target_exists_ok( SYMLINK [, TARGET] [, NAME] )

Ok is FILENAME is a symlink and it points to a existing file. With the
optional TARGET argument, the test fails if SYMLINK's target is not
TARGET. This test automatically skips if the operating system does not
support symlinks. If the file does not exist, the test fails.

The optional NAME parameter is the name of the test.

=cut

sub symlink_target_exists_ok
	{
    if( _no_symlinks_here() )
		{
		$Test->skip(
			"symlink_target_exists_ok doesn't work on systems without symlinks"
			);
		return;
		}

	my $file = shift;
	my $dest = shift || readlink( $file );
	my $name = shift || "$file is a symlink";

	unless( -l $file )
		{
		$Test->diag( "File [$file] is not a symlink!" );
		return $Test->ok( 0, $name );
		}

	unless( -e $dest )
		{
		$Test->diag( "Symlink [$file] points to non-existent target [$dest]!" );
		return $Test->ok( 0, $name );
		}

	my $actual = readlink( $file );
	unless( $dest eq $actual )
		{
		$Test->diag(
			"Symlink [$file] points to\n\t$actual\nexpected\n\t$dest\n\n" );
		return $Test->ok( 0, $name );
		}

	$Test->ok( 1, $name );
	}

=item symlink_target_dangles_ok( SYMLINK [, NAME] )

Ok if FILENAME is a symlink and if it doesn't point to a existing
file. This test automatically skips if the operating system does not
support symlinks. If the file does not exist, the test fails.

The optional NAME parameter is the name of the test.

=cut

sub symlink_target_dangles_ok
	{
    if( _no_symlinks_here() )
		{
		$Test->skip(
			"symlink_target_exists_ok doesn't work on systems without symlinks" );
		return;
		}

	my $file = shift;
	my $dest = readlink( $file );
	my $name = shift || "$file is a symlink";

	unless( -l $file )
		{
		$Test->diag( "File [$file] is not a symlink!" );
		return $Test->ok( 0, $name );
		}

	if( -e $dest )
		{
		$Test->diag(
			"Symlink [$file] points to existing file [$dest] but shouldn't!" );
		return $Test->ok( 0, $name );
		}

	$Test->ok( 1, $name );
	}

=item link_count_is_ok( FILE, LINK_COUNT [, NAME] )

Ok if the link count to FILE is LINK_COUNT. LINK_COUNT is interpreted
as an integer. A LINK_COUNT that evaluates to 0 returns Ok if the file
does not exist. This test automatically skips if the operating system
does not support symlinks. If the file does not exist, the test fails.

The optional NAME parameter is the name of the test.


=cut

sub link_count_is_ok
	{
    if( _no_symlinks_here() )
		{
		$Test->skip(
			"link_count_is_ok doesn't work on systems without symlinks" );
		return;
		}

	my $file   = shift;
	my $count  = int( 0 + shift );

	my $name   = shift || "$file has a link count of [$count]";

	my $actual = (stat $file )[3];

	unless( $actual == $count )
		{
		$Test->diag(
			"File [$file] points has [$actual] links: expected [$count]!" );
		return $Test->ok( 0, $name );
		}

	$Test->ok( 1, $name );
	}

=item link_count_gt_ok( FILE, LINK_COUNT [, NAME] )

Ok if the link count to FILE is greater than LINK_COUNT. LINK_COUNT is
interpreted as an integer. A LINK_COUNT that evaluates to 0 returns Ok
if the file has at least one link. This test automatically skips if
the operating system does not support symlinks. If the file does not
exist, the test fails.

The optional NAME parameter is the name of the test.

=cut

sub link_count_gt_ok
	{
    if( _no_symlinks_here() )
		{
		$Test->skip(
			"link_count_gt_ok doesn't work on systems without symlinks" );
		return;
		}

	my $file   = shift;
	my $count  = int( 0 + shift );

	my $name   = shift || "$file has a link count of [$count]";

	my $actual = (stat $file )[3];

	unless( $actual > $count )
		{
		$Test->diag(
			"File [$file] points has [$actual] links: ".
			"expected more than [$count]!" );
		return $Test->ok( 0, $name );
		}

	$Test->ok( 1, $name );
	}

=item link_count_lt_ok( FILE, LINK_COUNT [, NAME] )

Ok if the link count to FILE is less than LINK_COUNT. LINK_COUNT is
interpreted as an integer. A LINK_COUNT that evaluates to 0 returns Ok
if the file has at least one link. This test automatically skips if
the operating system does not support symlinks. If the file does not
exist, the test fails.

The optional NAME parameter is the name of the test.

=cut

sub link_count_lt_ok
	{
    if( _no_symlinks_here() )
		{
		$Test->skip(
			"link_count_lt_ok doesn't work on systems without symlinks" );
		return;
		}

	my $file   = shift;
	my $count  = int( 0 + shift );

	my $name   = shift || "$file has a link count of [$count]";

	my $actual = (stat $file )[3];

	unless( $actual < $count )
		{
		$Test->diag(
			"File [$file] points has [$actual] links: ".
			"expected more than [$count]!" );
		return $Test->ok( 0, $name );
		}

	$Test->ok( 1, $name );
	}


# owner_is, owner_isnt, group_is and group_isnt are almost
# identical in the beginning, so I'm writing a skeleton they can all use.
# I can't think of a better name...
sub _dm_skeleton
	{
	if( _obviously_non_multi_user() )
		{
		my $calling_sub = (caller(1))[3];
		$Test->skip( $calling_sub . " only works on a multi-user OS" );
		return 'skip';
		}

	my $filename      = _normalize( shift );
	my $testing_for   = shift;
	my $name          = shift;

	unless( defined $filename )
		{
		$Test->diag( "File name not specified" );
		return $Test->ok( 0, $name );
		}

	unless( -e $filename )
		{
		$Test->diag( "File [$filename] does not exist" );
		return $Test->ok( 0, $name );
		}

	return;
	}

=item owner_is( FILE , OWNER [, NAME] )

Ok if FILE's owner is the same as OWNER.  OWNER may be a text user name
or a numeric userid.  Test skips on Dos, and Mac OS <= 9.
If the file does not exist, the test fails.

The optional NAME parameter is the name of the test.

Contributed by Dylan Martin

=cut

sub owner_is
	{
	my $filename      = shift;
	my $owner         = shift;
	my $name          = shift || "$filename belongs to $owner";

	my $err = _dm_skeleton( $filename, $owner, $name );
	return if( defined( $err ) && $err eq 'skip' );
	return $err if defined($err);

	my $owner_uid = _get_uid( $owner );

	my $file_uid = ( stat $filename )[4];

	unless( defined $file_uid )
		{
		$Test->skip("stat failed to return owner uid for $filename");
		return;
		}

	return $Test->ok( 1, $name ) if $file_uid == $owner_uid;

	my $real_owner = ( getpwuid $file_uid )[0];
	unless( defined $real_owner )
		{
		$Test->diag("File does not belong to $owner");
		return $Test->ok( 0, $name );
		}

	$Test->diag( "File [$filename] belongs to $real_owner ($file_uid), ".
			"not $owner ($owner_uid)" );
	return $Test->ok( 0, $name );
	}

=item owner_isnt( FILE, OWNER [, NAME] )

Ok if FILE's owner is not the same as OWNER.  OWNER may be a text user name
or a numeric userid.  Test skips on Dos and Mac OS <= 9.  If the file
does not exist, the test fails.

The optional NAME parameter is the name of the test.

Contributed by Dylan Martin

=cut

sub owner_isnt
	{
	my $filename      = shift;
	my $owner         = shift;
	my $name          = shift || "$filename belongs to $owner";

	my $err = _dm_skeleton( $filename, $owner, $name );
	return if( defined( $err ) && $err eq 'skip' );
	return $err if defined($err);

	my $owner_uid = _get_uid( $owner );
	my $file_uid  = ( stat $filename )[4];

	return $Test->ok( 1, $name ) if $file_uid != $owner_uid;

	$Test->diag( "File [$filename] belongs to $owner ($owner_uid)" );
	return $Test->ok( 0, $name );
	}

=item group_is( FILE , GROUP [, NAME] )

Ok if FILE's group is the same as GROUP.  GROUP may be a text group name or
a numeric group id.  Test skips on Dos, Mac OS <= 9 and any other operating
systems that do not support getpwuid() and friends.  If the file does not
exist, the test fails.

The optional NAME parameter is the name of the test.

Contributed by Dylan Martin

=cut

sub group_is
 	{
	my $filename      = shift;
	my $group         = shift;
	my $name          = ( shift || "$filename belongs to group $group" );

	my $err = _dm_skeleton( $filename, $group, $name );
	return if( defined( $err ) && $err eq 'skip' );
	return $err if defined($err);

	my $group_gid = _get_gid( $group );
	my $file_gid  = ( stat $filename )[5];

	unless( defined $file_gid )
 		{
		$Test->skip("stat failed to return group gid for $filename");
		return;
		}

	return $Test->ok( 1, $name ) if $file_gid == $group_gid;

	my $real_group = ( getgrgid $file_gid )[0];
	unless( defined $real_group )
		{
		$Test->diag("File does not belong to $group");
 		return $Test->ok( 0, $name );
 		}

	$Test->diag( "File [$filename] belongs to $real_group ($file_gid), ".
			"not $group ($group_gid)" );

	return $Test->ok( 0, $name );
	}

=item group_isnt( FILE , GROUP [, NAME] )

Ok if FILE's group is not the same as GROUP.  GROUP may be a text group name or
a numeric group id.  Test skips on Dos, Mac OS <= 9 and any other operating
systems that do not support getpwuid() and friends.  If the file does not
exist, the test fails.

The optional NAME parameter is the name of the test.

Contributed by Dylan Martin

=cut

sub group_isnt
	{
	my $filename      = shift;
	my $group         = shift;
	my $name          = shift || "$filename does not belong to group $group";

	my $err = _dm_skeleton( $filename, $group, $name );
	return if( defined( $err ) && $err eq 'skip' );
	return $err if defined($err);

	my $group_gid = _get_gid( $group );
	my $file_gid  = ( stat $filename )[5];

	unless( defined $file_gid )
		{
		$Test->skip("stat failed to return group gid for $filename");
		return;
		}

	return $Test->ok( 1, $name ) if $file_gid != $group_gid;

	$Test->diag( "File [$filename] belongs to $group ($group_gid)" );
 		return $Test->ok( 0, $name );
	}

sub _get_uid
	{
	my $owner = shift;
	my $owner_uid;

	if ($owner =~ /^\d+/)
		{
		$owner_uid = $owner;
		$owner = ( getpwuid $owner )[0];
		}
	else
		{
		$owner_uid = (getpwnam($owner))[2];
		}

	$owner_uid;
	}

sub _get_gid
	{
	my $group = shift;
	my $group_uid;

	if ($group =~ /^\d+/)
		{
		$group_uid = $group;
		$group = ( getgrgid $group )[0];
		}
	else
		{
		$group_uid = (getgrnam($group))[2];
		}

	$group_uid;
	}

=back

=head1 TO DO

* check properties for other users (readable_by_root, for instance)

* check times

* check number of links to file

* check path parts (directory, filename, extension)

=head1 SEE ALSO

L<Test::Builder>,
L<Test::More>

=head1 SOURCE AVAILABILITY

This source is part of a SourceForge project which always has the
latest sources in CVS, as well as all of the previous releases.

	http://sourceforge.net/projects/brian-d-foy/

If, for some reason, I disappear from the world, one of the other
members of the project can shepherd this module appropriately.

=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 CREDITS

Shawn Sorichetti C<< <ssoriche@coloredblocks.net> >> provided
some functions.

Tom Metro helped me figure out some Windows capabilities.

Dylan Martin added C<owner_is> and C<owner_isnt>

=head1 COPYRIGHT

Copyright 2002-2006, brian d foy, All Rights Reserved

You may use, modify, and distribute this under the same terms
as Perl itself.

=cut

"The quick brown fox jumped over the lazy dog";
