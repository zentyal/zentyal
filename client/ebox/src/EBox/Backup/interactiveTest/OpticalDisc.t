use strict;
use warnings;


use Test::More qw(no_plan);
use Test::Exception;
use Perl6::Junction qw(all);
use EBox::Test;

use lib '../../..';
use_ok(' EBox::Backup::OpticalDisc');

EBox::Test::activateEBoxTestStubs();
diag "This test must be run as root otherwise some parts may fail";

my @supportedMedia = qw(CD-R CD-RW DVD-R DVD-RW no_disc);

my $dev = devicePrompt();
my $expectedMedia;
while (($expectedMedia = mediaPrompt()) ne 'quit') {
  if ($expectedMedia ne all(@supportedMedia)) {
    diag "Unknowm media type: $expectedMedia";
    next;
  }
  my $media;
  lives_ok {$media = EBox::Backup::OpticalDisc::media($dev) } 'Trying to get media info';
  is $media, $expectedMedia, 'Checking media info';
}



sub mediaPrompt
{
  diag "Insert disc and please type in the media used (@supportedMedia) or 'quit' to quit\n";
  my $media = <>;
  chomp $media;
  return $media;
}

sub devicePrompt
{
  diag "Please type in the recorder device file(ex: /dev/cdrom)\n";
  my $dev = <>;
  chomp $dev;
  return $dev;
}

1;
