use strict;
use warnings;
use Cwd;

use File::Slurp qw(read_file);

use lib '../..';
use EBox::Test::Mason;

use Test::More tests => 4;

my $template = '../amavisd.conf.mas';

my $printOutput = 0;
my $outputFileBase  = '/tmp/amavisd.conf';  # XXX FIXME file separator in mason tests
system "rm -rf $outputFileBase*";


my @mandatoryParams = (
		       myhostname => 'macaco.monos.org',
		       mydomain   => 'monos.org',
		       
		       ldapBase  => 'ea',
		       ldapQueryFilter  => 'ea',
		       ldapBindDn  => 'ea',
		       ldapBindPasswd  => 'ea',

		       adminAddress => 'alpha@macaco.org',

		       allowedExternalMTAs => [],
);


my @cases = (
	     # all active
	     [ @mandatoryParams, clamdSocket => '/var/run/clam/clamd.socket'	     ],
	     # without antivurus
	     [ @mandatoryParams, antivirusActive => 0],
	    );

my $fileCounter = 0;  # XXX FIXME file separator in mason tests
foreach my $params (@cases) {
   $fileCounter += 1; # XXX FIXME file separator in mason tests
   my $outputFile = $outputFileBase . $fileCounter; # XXX FIXME file separator in mason tests

  my $execOk;
  $execOk = EBox::Test::Mason::checkTemplateExecution(template => $template, templateParams => $params, printOutput => $printOutput, outputFile => $outputFile);

 SKIP:{
    skip 'Configuration file has not been correctly created', 1 if not $execOk;
    _checkConfFile($outputFile);
  }
}



sub _checkConfFile
{
  my ($file) = @_;

  system "grep -v '------' $file > $file"; # XXX FIXME file separator in mason tests

  my $testName = 'Checking wether the amavisd conf file passes the perl compilation';
  my $code =  read_file($file);
  eval $code;
  if ($@) {
    fail $testName;
    diag "Perl evaluation of $file output: $@";
  }
  else {
    pass $testName;
  }

}

1;
