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

my @supportedMedia = qw(CD-R CD-RW DVD-R DVD-ROM DVD-RW no_disc);

my $dev = devicePrompt();
my $expectedMedia;
while (1) {
  my ($expectedMedia, $expectedWritable) = mediaPrompt();
  if ($expectedMedia ne all(@supportedMedia)) {
    diag "Unknown media type: $expectedMedia";
    next;
  }
  my $mediaInfo;
  lives_ok {$mediaInfo = EBox::Backup::OpticalDisc::media($dev) } 'Trying to get media info';
  is $mediaInfo->{media}, $expectedMedia, 'Checking media type';
  ok $mediaInfo->{writable} , 'Checking writable attribute' if $expectedWritable;
  ok !$mediaInfo->{writable} , 'Checking writable attribute' if !$expectedWritable;
}



sub mediaPrompt
{
  print "Insert disc and please type in the media used (@supportedMedia) and if is writtable (0 or 1) or 'quit' to quit\n";
  my $input = <>;
  chomp $input;

  if ($input eq 'quit') {
    exit 0;
  }
  
  my ($media, $writable) = split '\s+', $input;
  
  return ($media, $writable);
}

sub devicePrompt
{
  print "Please type in the recorder device file(ex: /dev/cdrom)\n";
  my $dev = <>;
  chomp $dev;
  return $dev;
}

1;
