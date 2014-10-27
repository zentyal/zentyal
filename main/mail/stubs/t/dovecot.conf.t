use strict;
use warnings;
use Cwd;

use File::Slurp qw(read_file);

use EBox::Test::Mason;

use Test::More tests => 1;

my $template = 'mail/stubs/dovecot.conf.mas';

my $printOutput = 0;
my $outputFileBase  = '/tmp/dovecot.conf';  # XXX FIXME file separator in mason tests
system "rm -rf $outputFileBase*";

my @cases = (
             [ uid => 1000, gid => 1000, protocols => ['pop', 'imap'], openchange => 1, firstValidUid => 1000,
               firstValidGid => 1000, mailboxesDir => '/var/mail', postmasterAddress => 'postmaster@example.com',
               antispamPlugin => {name => 'amavis'},
               openchangePlugin => {enabled => 1, host => 'broker.local', port => 1234, user => 'user1', pass => 'pass',
                                    vhost => 'broker-vhost.local', 'exchange' => 'exchange_scks', 'routing' => 'routingKey'},
               keytabPath => '/var/keytab', gssapiHostname => { value1 => 'gssapiHostname' } ],
            );

my $fileCounter = 0;  # XXX FIXME file separator in mason tests
foreach my $params (@cases) {
   $fileCounter += 1; # XXX FIXME file separator in mason tests
   my $outputFile = $outputFileBase . $fileCounter; # XXX FIXME file separator in mason tests

  my $execOk;
  $execOk = EBox::Test::Mason::checkTemplateExecution(template => $template, templateParams => $params, printOutput => $printOutput, outputFile => $outputFile);
}

1;
