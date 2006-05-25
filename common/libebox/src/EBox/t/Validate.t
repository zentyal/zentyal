# Description:
use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;

use lib '../..';

BEGIN { use_ok('EBox::Validate') }; 

checkFilePathTest();
checkAbsoluteFilePathTest();

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

1;
