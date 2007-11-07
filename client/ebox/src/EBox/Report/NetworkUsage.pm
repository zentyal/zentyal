package EBox::Report::NetworkUsage;
#
use strict;
use warnings;

use RRDs;

use EBox::Gettext;
use EBox::Exceptions::Internal;

use Params::Validate qw(validate);

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


# XXX add params validation
sub graph
{
  my %params = @_;

  my @dataset  = @{ $params{dataset} };
  my $startTime = $params{startTime};
  my $title    = $params{title};

  my $file     = $params{file};

  my $verticalLabel = __('bytes/second');

  my $step = 1; # time step one second

  my @defs;
  my @lines;
  my $i = 0;
  foreach my $ds (@dataset) {
    my $rrd    = $ds->{rrd};
    my $colour = $ds->{colour};
    my $legend = $ds->{legend};

    my $vname = "v$i";

    push @defs, "DEF:$vname=$rrd:bps:AVERAGE";
    push @lines, "LINE2:$vname#$colour:$legend";

    $i++;
  }



  RRDs::graph(
	      $file,  
	      "-s $startTime",
	      "-S $step",
	      "-t $title",
	      "-v $verticalLabel",
	      @defs,
	      @lines,
	     );

  my $error = RRDs::error;
  if ($error) {
    throw EBox::Exceptions::Internal("rrdgraph error: $error");
  }
}

1;
