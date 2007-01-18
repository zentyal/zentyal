# Description:
use strict;
use warnings;

use Test::More tests => 100;
use Test::Exception;
use Fatal qw(mkdir);

use lib '../..';

BEGIN { use_ok('EBox::Validate') }; 

checkFilePathTest();
checkAbsoluteFilePathTest();
checkIsPrivateDir();
checkHostTest();

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

  mkdir($dir, 0777);		# public access
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

    my @deviantCases = qw(
		       	);

    if ($relativeIsValid) {
	push @straightCases, @relativePathsCases;
    }
    else {
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
  my @straightCases  = (
                          'macaco.monos.org',  # valid hostname
                          'isolatedMonkey',    # valid stand-alone hostname
                          '192.168.45.21',     # valid ip address
		       );
  my @deviantCases  = (
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


1;
