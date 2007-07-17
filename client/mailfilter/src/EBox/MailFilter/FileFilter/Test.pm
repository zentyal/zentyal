package EBox::MailFilter::FileFilter::Test;
# package:
use strict;
use warnings;

use base 'EBox::Test::Class';

use EBox::Test;
use Test::File;
use Test::More;
use Test::Exception;
use Test::MockObject;
use Test::Differences;
use Perl6::Junction qw(any);

use lib '../../..';
use EBox::MailFilter;






sub setUpConfiguration : Test(setup)
{
    my ($self) = @_;

    my @config = (
		  '/ebox/modules/mailfilter/file_filter/holder' => 1,


		  '/ebox/modules/mailfilter/clamav/active' => 0,
		  '/ebox/modules/mailfilter/spamassassin/active' => 1,
		  );

    EBox::GConfModule::TestStub::setConfig(@config);
    EBox::Global::TestStub::setEBoxModule('mailfilter' => 'EBox::MailFilter');

 #   EBox::Config::TestStub::setConfigKeys('tmp' => '/tmp');
}


sub clearConfiguration : Test(teardown)
{
    EBox::GConfModule::TestStub::setConfig();
}




sub _instanceTest : Test(2)
{
  my $ff;
  lives_ok { 
    $ff = _ffilterInstance();
  } 'Creating a files filter object instance';

  isa_ok($ff, 'EBox::MailFilter::FileFilter');
}



sub _ffilterInstance
{
  my $mailfilter = EBox::Global->modInstance('mailfilter');
  return $mailfilter->fileFilter();
}


sub testMimeTypes : Test(21)
{
  my $ffilter = _ffilterInstance();

  my @goodCases = (
		   ['video/avi' => 1],
		   ['application/octet-stream' => 0],
		  );
  my @badCases = (
		  ['video/' => 1],
		  ['/avi' => 0],
		  ['exe' => 1],
		  ['application&exe' => 1],
		 );

  my %expected;

  foreach my $case (@goodCases) {
    my ($mimeType, $allowed) = @{ $case };

    lives_ok { $ffilter->setMimeType($mimeType, $allowed)  }
      "Setting the mime type $mimeType";

    $expected{$mimeType} = $allowed;
    _checkFileFilterContents($ffilter, 'mimeTypes', \%expected);
  }

  foreach my $case (@badCases) {
    my ($mimeType, $allowed) = @{ $case };  
#    $ffilter->_checkMimeType($mimeType);
    dies_ok { $ffilter->setMimeType($mimeType, $allowed)  }
      "checking wether setting bad mime type $mimeType raises error";
  }

  diag 'checking that failed insertions in the database has not added any data';
  _checkFileFilterContents($ffilter, 'mimeTypes', \%expected);

  diag 'removal cases';

  dies_ok { $ffilter->unsetMimeType('type/inexistent')   } 
    'checking wether the removal of unexistent type raises error';
  _checkFileFilterContents($ffilter, 'mimeTypes', \%expected);

  
    foreach my $case (@goodCases) {
    my ($mimeType, $allowed) = @{ $case };

    lives_ok { $ffilter->unsetMimeType($mimeType)  }
      " checking the unsetting the mime type $mimeType";

    delete $expected{$mimeType};
    _checkFileFilterContents($ffilter, 'mimeTypes', \%expected);
  }
}


sub testFileExtensions : Test(20)
{
  my $ffilter = _ffilterInstance();

  my @goodCases = (
		   ['avi' => 1],
		   ['exe' => 0],
		  );
  my @badCases = (
		  ['.exe' => 1],
		  ['/app.exe' => 0],
		  ['application/octet-stream' => 1],
		 );
  my %expected;

  foreach my $case (@goodCases) {
    my ($extension, $allowed) = @{ $case };

    lives_ok { $ffilter->setExtension($extension, $allowed)  }
      "Setting the file extension $extension";

    $expected{$extension} = $allowed;
    _checkFileFilterContents($ffilter, 'extensions', \%expected);
  }

  foreach my $case (@badCases) {
    my ($extension, $allowed) = @{ $case };  
    dies_ok { $ffilter->setExtension($extension, $allowed)  }
      "checking wether setting bad file extension $extension raises error";
  }

  diag 'checking that failed insertions in the database has not added any data';
  _checkFileFilterContents($ffilter, 'extensions', \%expected);

  diag 'removal cases';

  dies_ok { $ffilter->unsetExtension('inexistent')   } 
    'checking wether the removal of unexistent extension raises error';
  _checkFileFilterContents($ffilter, 'extensions', \%expected);

  foreach my $case (@goodCases) {
    my ($extension, $allowed) = @{ $case };

    lives_ok { $ffilter->unsetExtension($extension)  }
      " checking the unsetting the file extension $extension";

    delete $expected{$extension};
    _checkFileFilterContents($ffilter, 'extensions', \%expected);
  }
}




sub _checkFileFilterContents
{
  my ($ffilter, $typeGetter, $expected) = @_;

  my $actual = $ffilter->$typeGetter();
  foreach (values %{ $actual }) {
    $_ = $_ ? 1 : 0;
  }

  eq_or_diff  $actual, $expected, "checking contents of file filter database obtained with $typeGetter()";

  my $regexes_r = $ffilter->bannedFilesRegexes;
  lives_ok {
    foreach (@{ $regexes_r }) {
      eval   "qr{$_};";
      $@ and die "$@";
    }
  } 'checking that regexes from file contents are correct';
}


1;
