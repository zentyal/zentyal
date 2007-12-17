package EBox::Network::Report::ByteRate::Test;
use base 'EBox::Test::Class';
#
use strict;
use warnings;


use Test::Exception;
use Test::MockObject;
use Test::More;

use lib '../../../..';

use EBox::Network::Report::ByteRate;

my %bpsByRRD;

sub _fakeAddBpsToRRD : Test(startup)
{
  my $fakeSub_r = sub {
    my ($rrd, $bps) = @_;
    $bpsByRRD{$rrd} += $bps;
  };

  Test::MockObject->fake_module(
				'EBox::Network::Report::ByteRate',
				_addBpsToRRD => $fakeSub_r,
			       );
}


sub _clearRRDs : Test(setup)
{
  %bpsByRRD = ();
}



sub addBpsTest : Test(4)
{
  my %expectedRRDs;

  my $wwwPort = 80;
  my $wwwRRD  =  EBox::Network::Report::ByteRate::serviceRRD('www');
  my $sshPort = 22; 
  my $sshRRD  =  EBox::Network::Report::ByteRate::serviceRRD('ssh'); 

  my $src1    = '192.168.45.3';
  my $src1RRD = EBox::Network::Report::ByteRate::srcRRD($src1);
  my $src2    = '10.45.23.12';
  my $src2RRD = EBox::Network::Report::ByteRate::srcRRD($src2);
  
  my $src1WwwRRD = EBox::Network::Report::ByteRate::srcAndServiceRRD($src1, 'www');
  my $src2WwwRRD = EBox::Network::Report::ByteRate::srcAndServiceRRD($src2, 'www');
  my $src1SshRRD = EBox::Network::Report::ByteRate::srcAndServiceRRD($src1, 'ssh');
  my $src2SshRRD = EBox::Network::Report::ByteRate::srcAndServiceRRD($src2, 'ssh');



  EBox::Network::Report::ByteRate::addBps(
					 proto => 'tcp',
					 src   => $src1,
					 sport => 10000,
					 dst   => '45.23.12.12',
					 dport => $wwwPort,
					 bps => 1,
					); 

  

  $expectedRRDs{$src1RRD} +=  1;
  $expectedRRDs{$wwwRRD} += 1;
  $expectedRRDs{$src1WwwRRD} +=  1;


  is_deeply \%bpsByRRD, {}, 'checking that before flushing the bps the RRDs have not any data';

  EBox::Network::Report::ByteRate->flushBps();

  is_deeply \%bpsByRRD, \%expectedRRDs, 'checking data after flushing the bps ';


  EBox::Network::Report::ByteRate::addBps(
					 proto => 'tcp',
					 src   => $src2,
					 sport => 10000,
					 dst   => '45.23.12.12',
					 dport => $wwwPort,
					 bps => 1,
					); 
  $expectedRRDs{$src2RRD} += 1;
  $expectedRRDs{$wwwRRD}  += 1;
  $expectedRRDs{$src2WwwRRD} += 1;
  

  EBox::Network::Report::ByteRate::addBps(
					 proto => 'tcp',
					 src   => $src1,
					 sport => 10000,
					 dst   => '45.23.12.12',
					 dport => $wwwPort,
					 bps => 1,
					); 

  $expectedRRDs{$src1RRD} += 1;
  $expectedRRDs{$wwwRRD}  += 1;
  $expectedRRDs{$src1WwwRRD} += 1;

  EBox::Network::Report::ByteRate->flushBps();

  is_deeply \%bpsByRRD, \%expectedRRDs, 'checking data after two more adds ';

  EBox::Network::Report::ByteRate::addBps(
					 proto => 'tcp',
					 src   => $src2,
					 sport => 10000,
					 dst   => '45.23.12.12',
					 dport => $sshPort,
					 bps => 2,
					); 
  $expectedRRDs{$src2RRD} += 2;
  $expectedRRDs{$sshRRD}  += 2;
  $expectedRRDs{$src2SshRRD} += 2;
  

  EBox::Network::Report::ByteRate::addBps(
					 proto => 'tcp',
					 src   => $src1,
					 sport => 10000,
					 dst   => '45.23.12.12',
					 dport => $sshPort,
					 bps => 1,
					); 

  $expectedRRDs{$src1RRD} += 1;
  $expectedRRDs{$sshRRD}  += 1;
  $expectedRRDs{$src1SshRRD} += 1;
  
  EBox::Network::Report::ByteRate->flushBps();

  is_deeply \%bpsByRRD, \%expectedRRDs, 'checking data after two more adds of another service';
}



sub addDeviantBpsTest : Test(12)
{

  my %goodCase = {
		  proto => 'tcp',
		  src   => '92.68.45.3',
		  sport => 10000,
		  dst   => '45.23.12.12',
		  dport => 70,
		  bps => 2,	  
		 };

  my %badValues = (
		   proto => 'bad_proto',
		   src   => '300.21.32.12',
		   sport => -1,
		   dst => 'bad_destination',
		   dport => 'bad_port',
		   bps => 'bad_bps',
		  );


  my @deviantCases;
  while (my ($param, $badValue) = each %badValues) {
    my %case = %goodCase;
    $case{$param}  = $badValue;

    push @deviantCases, [ %case ];
  }

  foreach my $case (@deviantCases) {
    lives_ok {
      EBox::Network::Report::ByteRate::addBps( @{ $case }); 
    } 'adding incorrect bps data';
    is keys %bpsByRRD, 0, 'checking that no bps data has been added when supplied bad data';
  }

}

1;
