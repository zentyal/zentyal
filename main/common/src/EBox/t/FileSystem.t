use strict;
use warnings;

use Test::More tests => 34;
use Test::Exception;
use Test::File;
use Fatal qw(mkdir);

use lib '../..';

use_ok('EBox::FileSystem');

checkNoRoot();
makePrivateDirTest();
cleanDirTest();
isSubdirTest();


sub checkNoRoot
{
    if ($> == 0 ) {
        die "This test script cannot be run as root";
    }
}

sub makePrivateDirTest
{
    dies_ok { EBox::FileSystem::makePrivateDir($0)  } 'Test for error when trying to create a private dir over a file';
    dies_ok { EBox::FileSystem::makePrivateDir('/home')  } 'Test for error when trying to create a private dir over a existent no private dir';

    my $dir ='/tmp/ebox.test.filesystem';
    system "rm -rf $dir";
    die $! if ($? != 0);

    mkdir ($dir, 0700);
    lives_ok {EBox::FileSystem::makePrivateDir($dir)  } 'Test for success when called upon a existent private dir';

    system "rm -rf $dir";
    die $! if ($? != 0);

    dies_ok { EBox::FileSystem::makePrivateDir('/gion.private')  } 'Test for error when failing to create a private dir';

    lives_ok {EBox::FileSystem::makePrivateDir($dir)  } 'Test for success when called to create a private dir';
}

sub cleanDirTest
{
    my $rootDir ='/tmp/ebox.test.filesystem.cleanDir';
    system "rm -rf $rootDir";
    die $! if ($? != 0);
    mkdir ($rootDir, 0700);

    dies_ok { EBox::FileSystem::cleanDir("/noPermission")  } "Testing for error if not write allowed";
    dies_ok { EBox::FileSystem::cleanDir("/root/inexistentThings/inexistentDir")  } "Testing for error when called in behalf of a unredeable dir";

    system "touch $rootDir/noDir";
    dies_ok { EBox::FileSystem::cleanDir("$rootDir/noDir")  } "Testing for error when trying to clean a no-dir file";

    my %dirsWithModes = (
        "$rootDir/hashParam" => 0750,
        "$rootDir/stringParam" => 0700,
    );
    my @cleanDirParams = ("$rootDir/stringParam", { name => "$rootDir/hashParam", mode =>  $dirsWithModes{"$rootDir/hashParam"} });

    lives_ok  {  EBox::FileSystem::cleanDir(@cleanDirParams) }, 'cleanDir() called with no existent dirs yet';

    diag 'Testing directory status';
    while (my ($dir, $mode) = each %dirsWithModes) {
        file_exists_ok($dir);
        file_mode_is($dir, $mode);
    }

# populating dirs
    system "touch $_/dirt" foreach keys %dirsWithModes;

    lives_ok  {  EBox::FileSystem::cleanDir(@cleanDirParams) }, 'cleanDir() called with existent dirs';

    diag 'Testing directory status after the cleaning';
    while (my ($dir, $mode) = each %dirsWithModes) {
        file_exists_ok($dir);
        file_mode_is($dir, $mode);
        system "ls $dir/*";
        ok ($? != 0), 'Checking that cleaned directory is empty';
    }
}

sub isSubdirTest
{
    my @trueCases = (
        [qw(/usr/var /)],
        [qw(/home/macaco/ /home)],
        [qw(/home/macaco/users/private/dir/ /home/macaco) ],
        [qw(/var/lib/zentyal/ /var/lib/)],
        # a dir is a subdir of itself:
        [qw(/home/macaco /home/macaco)],
    );

    my @falseCases = (
        [qw(/usr/var /home)],
    );

    # add inverted true cases
    push @falseCases, map {
        my ($subdir, $dir) = @{ $_ };
        ($subdir =~ m{$dir/?$}) ? () : [$dir, $subdir]; # discard cases when subDir and dir are the same
    } @trueCases;

    my @deviantCases = (
        [qw(. /usr)],
        [qw(/home home/macaco )],
        [qw(/usr/../home ../macaco)],
    );

    foreach my $case_r (@trueCases) {
        ok EBox::FileSystem::isSubdir(@{ $case_r }), "Checking isSubdir with a true case ( @{$case_r})" ;
    }
    foreach my $case_r (@falseCases) {
        ok !EBox::FileSystem::isSubdir(@{ $case_r }), "Checking isSubdir with a false case ( @{$case_r})" ;
    }
    foreach my $case_r (@deviantCases) {
        dies_ok { EBox::FileSystem::isSubdir(@{ $case_r }) } "Checking isSubdir with a deviant case that must raise error ( @{$case_r})" ;
    }
}

1;
