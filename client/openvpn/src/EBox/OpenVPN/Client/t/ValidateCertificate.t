#
use strict;
use warnings;

use EBox::TestStubs;

use Test::More tests => 10;
use Test::Exception;

use lib '../../../..';
use_ok ('EBox::OpenVPN::Client::ValidateCertificate');

EBox::TestStubs::activateTestStubs();
EBox::TestStubs::setEBoxConfigKeys(tmp => '/tmp');

# first set of certificates
my $caCert = 'testdata/cacert.pem';
my $cert   = 'testdata/cert.pem';
my $pkey   = 'testdata/pkey.pem';

# second set of certificates
my $caCert2 = 'testdata/cacert2.pem';
my $cert2   = 'testdata/cert2.pem';
my $pkey2   = 'testdata/pkey2.pem';


my $unrelatedFile = 'testdata/unrelated.pem';


my @goodCases = (
		 [$caCert, $cert, $pkey],
		 [$caCert2, $cert2, $pkey2],
		);
foreach my $case (@goodCases) {
  my @files =  @{ $case };
  lives_ok {
    EBox::OpenVPN::Client::ValidateCertificate::check(@files);
  } 'checking valid certificates files';
}



my @badCases = (
		# one unrelated file
		[$unrelatedFile, $cert, $pkey],
		[$caCert, $unrelatedFile, $pkey],
		[$caCert, $cert, $unrelatedFile],

		# duplicates files
		[$cert, $cert, $pkey],
		[$caCert, $caCert, $pkey],

		# caCert instead cert  and viceversa
		[$cert, $caCert, $pkey],
		# pkey instead cert  and viceversa
		[$caCert, $pkey, $cert],
	       );


foreach my $case (@badCases) {
  my @files =  @{ $case };
  dies_ok {
    EBox::OpenVPN::Client::ValidateCertificate::check(@files);
  } "checking bad certificates files: @files";
}

1;
