use strict;
use warnings;
use Cwd;

use File::Slurp qw(read_file);

use lib '../..';
use EBox::Test::Mason;

use Test::More tests => 1;

my $template = '../dovecot.conf.mas';

my $printOutput = 0;
my $outputFileBase  = '/tmp/dovecot.conf';  # XXX FIXME file separator in mason tests
system "rm -rf $outputFileBase*";





my @cases = (
             [ uid => 1000, gid => 1000, protocols => ['pop', 'imap'] ],
            );

my $fileCounter = 0;  # XXX FIXME file separator in mason tests
foreach my $params (@cases) {
   $fileCounter += 1; # XXX FIXME file separator in mason tests
   my $outputFile = $outputFileBase . $fileCounter; # XXX FIXME file separator in mason tests

  my $execOk;
  $execOk = EBox::Test::Mason::checkTemplateExecution(template => $template, templateParams => $params, printOutput => $printOutput, outputFile => $outputFile);

}





1;
