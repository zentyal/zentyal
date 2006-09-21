use strict;
use warnings;


use Test::More qw(no_plan);
use Test::Exception;
use Perl6::Junction qw(all);
use EBox::Test;

use lib '../../..';
use_ok(' EBox::Backup::OpticalDiscDrives');

EBox::Test::activateEBoxTestStubs();
diag "This test must be run as root otherwise some parts may fail";



my $dev = devicePrompt();

mediaPrompt();
lives_ok {EBox::Backup::OpticalDiscDrives::ejectDisc($dev) } 'Trying to eject media';
diag "We try now to eject a mounted disc";
mediaPrompt();
system "mount $dev";
$? == 0 or die "Can not mount $dev";
lives_ok {EBox::Backup::OpticalDiscDrives::ejectDisc($dev) } 'Trying to eject a mounted media';



sub mediaPrompt
{
  print "Insert disc and type enter";
  my $input = <>;
  chomp $input;
  exit 0 if $input eq 'quit';
  return $input;
}

sub devicePrompt
{
  print "Please type in the recorder device file(ex: /dev/cdrom)\n";
  my $dev = <>;
  chomp $dev;
  return $dev;
}

1;
