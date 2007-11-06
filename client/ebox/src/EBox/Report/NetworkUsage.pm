package EBox::Report::NetworkUsage;
#
use strict;
use warnings;

use RRDs;

# use Params::Validate qw(validate);

sub addBps
{
  my %params = @_;

#   validate (@_, {
# 		 proto => 1,
# 		 src => 1,
# 		 sport => 1,
# 		 dst => 1,
# 		 dport => 1,
# 		 bps => 1,
# 		});

  my $proto = $params{proto};
  my $src = $params{src};
  my $sport = $params{sport};
  my $dst = $params{dst};
  my $dport = $params{dport};
  my $bps  = $params{bps};


  my $service = _service($proto, $dport, $sport);


  addBpsToSrcRRD($src, $bps);
  addBpsToServiceRRD($service, $bps);
  addBpsToSrcAndServiceRRD($src, $service, $bps);
}


sub  _service
{
  my ($proto, $dport, $sport) = @_;
  my $service;

  $service = getservbyport($dport, $proto);

  if (not $service) {
    $service = getservbyport($sport, $proto);
  }

  if (not $service) {
    $service = $dport;
  }

  return $service;
}



sub _addBpsToRRD
{
  my ($rrd, $bps) = @_;

  RRDs::update($rrd, "N:$bps");
  my $err = RRDs::error;
  if ( $err) {
    die $err;
  }
}


sub _rrdDir
{
  return '/var/lib/ebox/tmp/';
}


sub srcRRD
{
  my ($src) = @_;
  my $rrd =  _rrdDir() . $src . '.rrd';
  _createRRDIfNotExists($rrd);
  return $rrd;
}

sub serviceRRD
{
  my ($service) = @_;
  my $rrd =  _rrdDir() . $service . '.rrd';
  _createRRDIfNotExists($rrd);
  return $rrd;
}


sub srcAndServiceRRD
{
  my ($src, $service) = @_;
  my $rrd =  _rrdDir() . "$src-$service.rrd";
  _createRRDIfNotExists($rrd);
  return $rrd;
}

sub _createRRDIfNotExists
{
  my ($rrd) = @_;
  if ( -f $rrd) {
    return;
  }

  RRDs::create(
	       $rrd,
	       '-s 1',
	       'DS:bps:GAUGE:60:0:U',
	       'RRA:AVERAGE:0.99:2:600',
	      );


  my $err = RRDs::error;
  if ( $err) {
    die $err;
  }
}


sub addBpsToSrcRRD
{
  my ($src, $bps) = @_;
  my $rrd = srcRRD($src);

  _addBpsToRRD($rrd, $bps);
}

sub addBpsToServiceRRD
{
  my ($service, $bps) = @_;

  my $rrd = serviceRRD($service);

  _addBpsToRRD($rrd, $bps);
}

sub addBpsToSrcAndServiceRRD
{
  my ($src, $service, $bps) = @_;

  my $rrd = srcAndServiceRRD($src, $service);

  _addBpsToRRD($rrd, $bps);
}



1;
