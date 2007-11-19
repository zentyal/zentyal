package EBox::Report::NetworkUsage;
#
use strict;
use warnings;

use RRDs;

use EBox::Gettext;
use EBox::Exceptions::Internal;

use Params::Validate qw(validate);

use constant SRC_COLOUR      => '0xFF0000';
use constant SERVICE_COLOUR =>  '0X00FF00';
use constant SRC_AND_SERVICE_COLOUR => '0x0000FF';

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

  _createRRDIfNotExists($rrd);

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

  return $rrd;
}

sub serviceRRD
{
  my ($service) = @_;
  my $rrd =  _rrdDir() . $service . '.rrd';
  return $rrd;
}


sub srcAndServiceRRD
{
  my ($src, $service) = @_;
  my $rrd =  _rrdDir() . "$src-$service.rrd";
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



sub srcGraph
{
  my (%params) = @_;

  my $src = delete $params{src};
  my $rrd = srcRRD($src);
  if (not -f $rrd) {
    throw EBox::Exceptions::External(
				     'Traffic data not found for source {src}',
				     src => $src,
				    );
  }

  my $dataset = [
		 _srcDatasetElement($src, $rrd),
		];


  my $title =__x('Network traffic from {src}', src => $src);

  graph(
	dataset => $dataset,
	title   => $title,
	%params,
       );
}

sub serviceGraph
{
  my (%params) = @_;

  my $service = delete $params{service};
  my $rrd = serviceRRD($service);
  if (not -f $rrd) {
    throw EBox::Exceptions::External(
				     'Traffic data not found for service {service}',
				     service => $service,
				    );
  }

  my $dataset = [
		 _serviceDatasetElement($service, $rrd),
		];


  my $title =__x('Network traffic for {service}', service => $service);

  graph(
	dataset => $dataset,
	title   => $title,
	%params,
     );
}

sub srcAndServiceGraph
{
  my (%params) = @_;

  my $src     = delete $params{src};
  my $service = delete $params{service};

  my $srcRRD = srcRRD($src);
  if (not -f $srcRRD) {
    throw EBox::Exceptions::External(
				     'Traffic data not found for source {src}',
				     src => $src,
				    );
  }

  my $serviceRRD  = serviceRRD($service);  
  if (not -f $serviceRRD) {
    throw EBox::Exceptions::External(
				     'Traffic data not found for service {service}',
				     service => $service,
				    );
  }

  my $srcAndServiceRRD = srcAndServiceRRD($src, $service);
  if (not -f $srcAndServiceRRD) {
    throw EBox::Exceptions::External(
				     'Traffic data not found for source {src} and service {service}',
				     src     => $src,
				     service => $service,
				    );
  }

  my $dataset = [
		 _srcAndServiceDatasetElement($src, $service, $srcAndServiceRRD),
		 _srcDatasetElement($src, $srcRRD),
		 _serviceDatasetElement($service, $serviceRRD),
		];


  my $title =__x('Network traffic from source {src} and for service {service}', 
		 src     => $src,
		 service => $service,
		);

  graph(
	dataset => $dataset,
	title   => $title,
	%params,
     );
}


sub _srcDatasetElement
{
  my ($src, $rrd) = @_;

  my $legend = __x("Traffic rate from {src}", src => $src);

  my $ds = {
	  rrd => $rrd,
	  legend => $legend,
	  colour => SRC_COLOUR,
	 };

  return $ds;
}

sub _serviceDatasetElement
{
  my ($service, $rrd) = @_;

  my $legend = __x("Traffic rate for {service}", service => $service);

  my $ds = {
	  rrd => $rrd,
	  legend => $legend,
	  colour => SERVICE_COLOUR,
	 };

  return $ds;
}

sub _srcAndServiceDatasetElement
{
  my ($src, $service, $rrd) = @_;

  my $legend = __x("{Traffic rate from {src} for {service}", 
		   src     => $src,
		   service => $service,
		  );

  my $ds = {
	  rrd => $rrd,
	  legend => $legend,
	  colour => SERVICE_COLOUR,
	 };

  return $ds;
}


1;
