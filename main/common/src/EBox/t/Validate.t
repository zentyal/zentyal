use strict;
use warnings;

use Test::More tests => 137;
use Test::Exception;
use Fatal qw(mkdir);

use lib '../..';

BEGIN { use_ok('EBox::Validate') };

checkFilePathTest();
checkAbsoluteFilePathTest();
checkIsPrivateDir();
checkHostTest();
checkEmailAddressTest();
checkIP6Test();
checkCIDRTest();
checkMACTest();

sub checkFilePathTest
{
    my $checkFilePath_r = \&EBox::Validate::checkFilePath;
    _checkPathSubsTest($checkFilePath_r, 1);
}

sub checkAbsoluteFilePathTest
{
    my $checkAbsoluteFilePath_r = \&EBox::Validate::checkAbsoluteFilePath;
    _checkPathSubsTest($checkAbsoluteFilePath_r, 0);
}

sub checkIsPrivateDir
{
    ok !EBox::Validate::isPrivateDir('/macaco'), 'Testing isPrivateDir in a inaccesible dir';
    dies_ok  { EBox::Validate::isPrivateDir('/macaco', 1) } 'The same  with exceptions';


    ok !EBox::Validate::isPrivateDir('/'), 'Testing isPrivateDir in a no-owned and public accesible dir';
    dies_ok  { EBox::Validate::isPrivateDir('/', 1) } 'The same  with exceptions';


    my $dir = '/tmp/ebox.test.validate';
    system "rm -rf $dir" ;
    die $! if ($? != 0);

    mkdir($dir, 0777);            # public access
        ok !EBox::Validate::isPrivateDir($dir), 'Testing isPrivateDir in a owned but public accesible dir';
    dies_ok  { EBox::Validate::isPrivateDir($dir, 1) } 'The same  with exceptions';

    system "rm -rf $dir";
    die $! if ($? != 0);

    mkdir ($dir, 0700);
    ok EBox::Validate::isPrivateDir($dir), 'Testing isPrivateDir in a owned and private dir';
    lives_ok  { EBox::Validate::isPrivateDir($dir, 1) } 'The same  with exceptions';
}

sub _checkPathSubsTest
{
    my ($checkPathSub_r, $relativeIsValid) = @_;

    my @straightCases = qw(
        /
        /home/javier/.emacs
        /home/javier/.emacs.d
        /home/javier/.emacs.d/auto-save-list
        /home/javier/.emacs.d/auto-save-list/.saves-12049-localhost.localdomain~
        /home/javier/src/ebox-platform/trunk/extra/esofttool/debian/rules
        /home/javier/src/ebox-platform/trunk/doc/.svn/format
        /var/log/ntpstats/peerstats.20060524
        /usr/share/doc/libtext-wrapi18n-perl/changelog.gz
        /usr/share/man/man1/lexgrog.1.gz
        /usr/share/man/man3/Apache::Resource.3pm.gz
        /usr/share/locale/ro/LC_MESSAGES/libgnomecanvas-2.0.mo
    );

    my @relativePathsCases = qw(
        .
        ..
        ../..
        .emacs
        .ea.txt.gz
        Config/t/cover_db/-home-javier-src-ebox-platform-trunk-common-libebox-src-EBox-pm.html
        home/javier/.emacs
        home/javier/.emacs.d
        home/javier/.emacs.d/auto-save-list
        home/javier/.emacs.d/auto-save-list/.saves-12049-localhost.localdomain~
        home/javier/src/ebox-platform/trunk/extra/esofttool/debian/rules
        ./home/javier/src/ebox-platform/trunk/doc/.svn/format
        ./var/log/ntpstats/peerstats.20060524
        ../share/doc/libtext-wrapi18n-perl/changelog.gz
        ../share/man/man1/lexgrog.1.gz
        ../share/man/man3/Apache::Resource.3pm.gz
        ../../share/locale/ro/LC_MESSAGES/libgnomecanvas-2.0.mo
         /home/../.emacs.d
         /home/./.emacs.d/../auto-save-list
         /home/./.emacs.d/auto-save-list/.saves-12049-localhost.localdomain~
    );

    my @deviantCases = qw();

    if ($relativeIsValid) {
        push @straightCases, @relativePathsCases;
    } else {
        push @deviantCases, @relativePathsCases;
    }

    foreach my $case (@straightCases) {
        my $name = "checking validation for straight case: $case";
        ok $checkPathSub_r->($case), $name;
    }

    foreach my $case (@deviantCases) {
        my $name = "checking validation error for deviant case: $case";
        ok !$checkPathSub_r->($case), $name;
        dies_ok { $checkPathSub_r->($case, $name) } "$name (with name parameter)";
    }
}

sub checkHostTest
{
    my @straightCases = (
        'macaco.monos.org',  # valid hostname
        'isolatedMonkey',    # valid stand-alone hostname
        '192.168.45.21',     # valid ip address
    );

    my @deviantCases = (
        '198.23.423.12',  # invalid ip address
        'badhost_.a.com', # invalid hostname
    );

    foreach my $case (@straightCases) {
        my $name = "checking validation for straight case: $case";
        ok EBox::Validate::checkHost($case), $name;
    }

    foreach my $case (@deviantCases) {
        my $name = "checking validation error for deviant case: $case";
        ok ! EBox::Validate::checkHost($case), $name;
        dies_ok {  EBox::Validate::checkHost($case, $name) } "$name (with name parameter)";
    }
}

sub checkEmailAddressTest
{
    my @straightCases = qw(macaco@monos.org homo.sapiens@primates.com mandrill+colorful@monos.org);
    my @deviantCases = ('macaco', ' macaco@monos.org');

    foreach my $case (@straightCases) {
        my $name = "checking validation for straight case: $case";
        ok EBox::Validate::checkEmailAddress($case), $name;
    }

    foreach my $case (@deviantCases) {
        my $name = "checking validation error for deviant case: $case";
        ok ! EBox::Validate::checkEmailAddress($case), $name;
        dies_ok {  EBox::Validate::checkEmailAddress($case, $name) } "$name (with name parameter)";
    }
}

sub checkIP6Test
{
    my @valid = (
        '2001:0db8:0000:0000:0000:0000:1428:57ab',
        '2001:0db8:0000:0000:0000::1428:57ab',
        '2001:0db8:0:0:0:0:1428:57ab',
        '2001:0db8:0:0::1428:57ab',
        '2001:0db8::1428:57ab',
        '2001:db8::1428:57ab',
    );

    my @invalid = (
        'macaco',
        '192.168.45.3',
    );

    foreach my $ip (@valid) {
        ok EBox::Validate::checkIP6($ip), 'checking wether checkIP6 recognizes valid addresses';
    }

    foreach my $ip (@invalid) {
        my $errorReturnValue = not EBox::Validate::checkIP6($ip);
        ok $errorReturnValue, 'checking wether checkIP6 signals invalid values wit its return value';;
        dies_ok {
            EBox::Validate::checkIP6($ip, 'error');
        } 'checking wether checkIP6 signals a invalid value raising exception';
    }
}

sub checkCIDRTest
{
    my @valid = (
        '192.168.0.0/16',
        '34.32.25.0/24',
    );

    my @invalid = (
        '192.168.34.12/0',
        '192.168.34.12',
        '34.32.25.1/24',
        ' 40.24.3.129/0',
    );

    foreach my $ip (@valid) {
        ok EBox::Validate::checkCIDR($ip), 'checking wether checkCIDR recognizes valid addresses';
    }

    foreach my $ip (@invalid) {
        my $errorReturnValue = not EBox::Validate::checkCIDR($ip);
        ok $errorReturnValue, 'checking wether checkCIDR signals invalid values wit its return value';;
        dies_ok {
            EBox::Validate::checkCIDR($ip, 'error');
        } 'checking wether checkCIDR signals a invalid value raising exception';
    }
}

sub checkMACTest
{
    my @valid = (
        "06:00:00:00:00:00",
        "00:0d:c5:d0:47:f2",
    );

    my @invalid = (
        "22:11:0d:c5:d0:47:f2" , # one suprefluous pair
        "0d:c5:d0:47:f2" , # one missing pair
        "00:0h:c5:d0:47:f2", # invalid hex character
        "0:0d:c5:d0:47:f2" , # one character
    );

    foreach my $ip (@valid) {
        ok EBox::Validate::checkMAC($ip), 'checking wether checkMAC recognizes valid addresses';
    }

    foreach my $ip (@invalid) {
        my $errorReturnValue = not EBox::Validate::checkMAC($ip);
        ok $errorReturnValue, 'checking wether checkMAC signals invalid values wit its return value';;
        dies_ok {
            EBox::Validate::checkMAC($ip, 'error');
        } 'checking wether checkMAC signals a invalid value raising exception';
    }
}

1;
