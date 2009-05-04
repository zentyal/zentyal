use strict;
use warnings;
use Cwd;

use File::Slurp qw(read_file);

use lib '../..';
use EBox::Test::Mason;


use Test::More qw(no_plan);

my $template = '../qmanager.mas';

my $printOutput = 0;
my $outputFileBase  = '/tmp/qmanager.html';  # XXX FIXME file separator in mason tests
system "rm -rf $outputFileBase*";


my @mandatoryParams = (
                       page => 0,
                       tpages => 1,
);


my @cases = (
             [  mqlist => [], getinfo => [], data => [], ], # no queue case
             [  
              mqlist => [
                         {
                          qid => '1291588A212*',
                          size => 4879,
                          atime => 'Fri Apr 24 12:21:09',
                          sender => 'MAILER-DAEMON',
                          recipients => ['suvenduo@deleteddomains.com'],
                          msg     => 'conversation with p.nsm.ctmail.com[216.163.188.57] timed out while receiving the initial server greeting',
                         },
                         # cover recip[ients undefined bug
                         {
                          qid => '1291588A212*',
                          size => 4879,
                          atime => 'Fri Apr 24 12:21:09',
                          sender => 'MAILER-DAEMON',
                          recipients => undef,
                          msg     => 'conversation with p.nsm.ctmail.com[216.163.188.57] timed out while receiving the initial server greeting',
                         },
                        ], 
              getinfo => 'none', 
              data => [], 
             ], 
            );

my $fileCounter = 0;  # XXX FIXME file separator in mason tests
foreach my $params (@cases) {
   $fileCounter += 1; # XXX FIXME file separator in mason tests
   my $outputFile = $outputFileBase . $fileCounter; # XXX FIXME file separator in mason tests

   my $templateParams = [
                         @mandatoryParams,
                         @{ $params }
                        ];

  my $execOk;
  $execOk = EBox::Test::Mason::checkTemplateExecution(template => $template, templateParams => $templateParams, printOutput => $printOutput, outputFile => $outputFile);

 SKIP:{
    skip 'Configuration file has not been correctly created', 1 if not $execOk;
    _checkConfFile($outputFile);
  }
}



sub _checkConfFile
{
  my ($file) = @_;

  system "grep -v -e '------' $file > $file"; # XXX FIXME file separator in mason tests

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
