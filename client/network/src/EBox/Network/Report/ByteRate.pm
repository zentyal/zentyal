# Copyright (C) 2007 Warp Networks S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package EBox::Network::Report::ByteRate;
#
#  XXX TODO: separate graphic function to their own package
use strict;
use warnings;

use RRDs;

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Config;
use EBox::Validate;
use EBox::NetWrappers;
use EBox::ColourRange;
use EBox::AbstractDaemon;

use EBox::Exceptions::Internal;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;

use EBox::Dashboard::Module;
use EBox::Dashboard::Section;
use EBox::Dashboard::Value;

use File::Glob qw(:glob);
use File::Basename;

use constant RRD_TTL => 601;
use constant RRD_TIME_STORED => 600; # store 10 minutes of data

use constant SRC_COLOUR      => 'FF0000';
use constant SERVICE_COLOUR =>  '00FF00';
use constant SRC_AND_SERVICE_COLOUR => '0000FF';



use constant MONITOR_DAEMON => '/usr/lib/ebox/ebox-traffic-monitor';
use constant MONITOR_DAEMON_NAME => 'ebox-traffic-monitor';
use constant MONITOR_PERIOD => 5;

use constant CONF_FILE => '/etc/jnettop.conf';

# Graph constants
use constant {
    GRAPH_HEIGHT => 135,
    GRAPH_WIDTH  => 540,
};

# Method: service
#
#       Check if the traffic monitoring is enabled or not
#
# Returns:
#
#       boolean - true if the traffic monitoring is enabled, false
#       otherwise
#
sub service
{
  my ($class) = @_;

  my $network  = EBox::Global->modInstance('network');
  my $enableForm = $network->model('EnableForm');
  return $enableForm->enabledValue();
}

# Method: running
#
#       Check whether the traffic monitoring daemon is running or not
#
# Returns:
#
#       boolean - true if the traffic monitoring daemon is running,
#       false otherwise
#
sub running
{
  my ($class) = @_;

  system 'pgrep -f ' . MONITOR_DAEMON;
  return ($? == 0);
}

# Method: _regenConfig
#
#       Regenerate the configuration file for the traffic
#       monitoring daemon and start/stop the service itself
#
sub _regenConfig
{
  my ($class) = @_;

  $class->_writeConfFile();

  my $service = $class->service();
  my $running = $class->running();

  if ($running) {
    $class->stopService();
  }

  if ( $service) {
    $class->startService();
  }

}

# Method: summary
#
#     See <EBox::Module::summary> for details
#
sub summary
{
    my ($class) = @_;

    if ( $class->service() ) {
        my $item = new EBox::Dashboard::Module(__('Traffic rate monitoring'));
        my $section = new EBox::Dashboard::Section('');
        $section->add(new EBox::Dashboard::Value(__('Status'), __('Running')));
        $item->add($section);
        return $item;
    } else {
        return undef;
    }
}

sub _ifaceToListenOn
{
  my $network  = EBox::Global->modInstance('network');
  my $settings = $network->model('ByteRateSettings');
  return $settings->ifaceValue();
}

# Method: startService
#
#     Start the traffic rate monitoring service
#
sub startService
{
  my ($class) = @_;

  my $cmd = MONITOR_DAEMON . ' time ' . MONITOR_PERIOD;
  $cmd  .= ' conffile ' . CONF_FILE;
  
    my $iface = _ifaceToListenOn();
  if ($iface ne 'all') {
    $cmd .= " iface $iface";
  }
  
  EBox::Sudo::root($cmd);
}

# Method: stopService
#
#     Stop the traffic rate monitoring service
#
sub stopService
{
  my ($class) = @_;

  my $pid = EBox::AbstractDaemon->pid(MONITOR_DAEMON_NAME);
  if (defined $pid) {
    EBox::Sudo::root('kill ' . $pid);
  }
  else {
    _warnIfDebug('Cannot stop traffic rate monitor because we cannot found its PID. Are you sure is running?');
  }

}


sub _writeConfFile
{
  my ($class) = @_;

  my $network = EBox::Global->modInstance('network');
  my @internalIfaces = @{ $network->InternalIfaces()  };

  my @localNets = map {
    my @nets;
    my %addresses = %{ EBox::NetWrappers::iface_addresses_with_netmask($_) };
    while (my ($addr, $mask) = each %addresses) {
      my $network = EBox::NetWrappers::ip_network($addr, $mask);
      push @nets, [$network, $mask];
    }

    @nets;

  } @internalIfaces;

  EBox::Module::Base::writeConfFileNoCheck(
			      CONF_FILE,
			      'network/jnettop.conf.mas',
			      [ localNetworks => \@localNets,  ],

			     );
}

my %srcBps;
my %serviceBps;
my %srcAndServiceBps;


# Method: addBps
#
#       register new traffic data. The data would not be added to the database
#       until the flushBps function is called
#
# Parameters:
#
#     src   - source of the trafic
#     dst   - destination of the traffic (currently unused)
#     proto - protocol of the traffic
#     sport - source port of the traffic
#     dport - destination port of the traffic
#     bps   - traffic rate in bytes per second
#
#      - Named parameters
sub addBps
{
  my %params = @_;


#  EBox::debug("addBps @_");

  my $src = $params{src};
  _checkAddr($src) or return;
  $src = escapeAddress($src);

  my $proto = $params{proto};
 _checkProto($proto) or return;

  my $sport = $params{sport};
 _checkPort($sport) or return;

#   XXX commented out, we do nothing with the destination parameter, for now...
#   my $dst = $params{dst};
#  _checkAddr($dst) or return;

  my $dport = $params{dport};
 _checkPort($dport) or return;

  my $bps  = $params{bps};
  _checkBps($bps) or return;


  my $service = _service($proto, $dport, $sport);


  # store the values waitng for flush..
  $srcBps{$src}         += $bps;
  $serviceBps{$service} += $bps;

  my $srcAndServiceId = "$src|$service";
  $srcAndServiceBps{$srcAndServiceId} += $bps;
}


#  Method: flushBps
#
#    flush the stored traffic data and write it to the various rrdtool databases   
#
# Warning: 
#   we trust in rrdtool extrapolation feature however to be sure we have
#   accurate rate is advised to have a flush frequency the closer possible to a
#   second
sub flushBps
{
  while (my ($src, $bps) = each %srcBps) {
    addBpsToSrcRRD($src, $bps);
  }

  while (my ($service, $bps) = each %serviceBps) {
    addBpsToServiceRRD($service, $bps);
  }
  
  while (my ($id, $bps) = each %srcAndServiceBps) {
    my ($src, $service) = split '\|', $id, 2;
    addBpsToSrcAndServiceRRD($src, $service, $bps);
  }
  
  %srcBps     = ();
  %serviceBps = ();
  %srcAndServiceBps = ();
}


# Method: _service
#
#   try to guess the traffic service's name. Wether a name is not found, the 
#   concatenation of the protocol and the destination port is used.
#
#  Parameters:
#      proto - traffic's protocol
#      dport - traffic's destination port
#      sport - traffic's source port
sub _service
{
  my ($proto, $dport, $sport) = @_;
  my $service;

  if ($proto eq 'arp') {
    return 'arp';
  }

  $service = getservbyport($dport, $proto);

  if (not $service and ($sport ne 'AGGR.')) {
    $service = getservbyport($sport, $proto);
  }

  if (not $service) {
    $service = $proto . $dport;
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
    throw EBox::Exceptions::Internal " error updating $rrd: $err";
  }
}


sub _rrdDir
{
  return EBox::Config::tmp() . 'rrd/';
}


# Method: srcRRD
#
#    get the RRD database file for the given source 
#
#  Parameters:
#    src - source address (escaped)
#
#  Returns:
#       RRD  file full path
sub srcRRD
{
  my ($src) = @_;
  
  my $rrd =  _rrdDir() . 'src-' . $src . '.rrd';

  return $rrd;
}

# Method: serviceRRD
#
#    get the RRD database file for the given service 
#
#  Parameters:
#    service - network service 
#
#  Returns:
#       RRD  file full path
sub serviceRRD
{
  my ($service) = @_;
  my $rrd =  _rrdDir() . 'service-'. $service . '.rrd';
  return $rrd;
}

# Method: srcAndServiceRRD
#
#    get the RRD database file for the combination of the given source and service
#
#  Parameters:
#    src - source address (escaped)
#    service - network service 
#
#  Returns:
#       RRD  file full path
sub srcAndServiceRRD
{
  my ($src, $service) = @_;
  my $rrd =  _rrdDir() . "src-$src-service-$service.rrd";
  return $rrd;
}

# Method: srcServicesRRD
#
#      Get those files which have the same source and different
#      services
#
# Parameters:
#
#      src - String the source IP address
#
# Returns:
#
#      array ref - containing those services which have a RRD table
#      associated with this source
#
sub srcServicesRRD
{
    my ($src) = @_;

    my $dir = _rrdDir();
    my @rrds = bsd_glob("$dir/src-$src-service-*.rrd");
    @rrds = @{ _activeRRDs(\@rrds) };

    my @servs = map { /service-(.*)\.rrd/ } @rrds;

    return \@servs;

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
	       'RRA:AVERAGE:0.99:2:' . RRD_TIME_STORED, # store 10 minutes of data
	      );


  my $err = RRDs::error;
  if ( $err) {
    die $err;
  }
}

# Method: addBpsToSrcRRD
#
#    add byte per seconds data point to source RRD
#
#  Parameters:
#    src - source address (escaped)
#    bps - bytes per second to add
#
sub addBpsToSrcRRD
{
  my ($src, $bps) = @_;
  my $rrd = srcRRD($src);

  _addBpsToRRD($rrd, $bps);
}

# Method: addBpsToServiceRRD
#
#    add byte per seconds data point to service RRD
#
#  Parameters:
#    service  - network service
#    bps - bytes per second to add
#
sub addBpsToServiceRRD
{
  my ($service, $bps) = @_;

  my $rrd = serviceRRD($service);

  _addBpsToRRD($rrd, $bps);
}

# Method: addBpsToSrcAndServiceRRD
#
#    add byte per seconds data point to source and service combination RRD
#
#  Parameters:
#    src - source address (escaped)
#    service  - network service
#    bps - bytes per second to add
#
sub addBpsToSrcAndServiceRRD
{
  my ($src, $service, $bps) = @_;

  my $rrd = srcAndServiceRRD($src, $service);

  _addBpsToRRD($rrd, $bps);
}

sub _checkAddr
{
  my ($addr) = @_;

  my $valid = 0;

  if (EBox::Validate::checkIP($addr)) {   
    $valid = 1;
  }
  elsif (EBox::Validate::checkIP6($addr)) {
    $valid = 1;
  }
  elsif ($addr eq '0.0.0.0') { # especial case for ARP protocol
    $valid = 1;
  }

  if (not $valid) {
    _warnIfDebug("Incorrect address $addr, data will not be added to trafic statistics");
  }

  return $valid;
}


sub _checkPort
{
  my ($port) = @_;
  
  if (EBox::Validate::checkPort($port)) {  # normal port
    return 1;
  }
  elsif ($port eq 'AGGR.') { # aggregated port by jnettop
    return 1;
  }
  elsif ($port == 0) { # used when there is not port concept (i.e. ARP)
    return 1;
  }
  else {
    _warnIfDebug("Incorrect port $port, data will not be added to trafic statistics");
    return 0;
  }
}

sub _checkBps
{
  my ($bps) = @_;
  if (EBox::Validate::isANumber($bps) and ($bps >= 0)) {
    return 1;
  }
  else {
    _warnIfDebug("Incorrect bytes per second: $bps, data will not be added to trafic statistics");
    return 0;
  }
}




my %VALID_PROTOCOLS = (tcp => 1, udp => 1, arp => 1, icmp => 1, icmp6 => 1, ether => 1 );

sub _checkProto
{
  my ($proto) = @_;

  if (exists $VALID_PROTOCOLS{$proto}) {
    return 1;
  }
  else {
    _warnIfDebug("Incorrect protocol $proto, data will not be added to traffic statistics");
    return 0;
  }

}


# we only log the warning if debug active bz otherwise we can fill the hard disk
sub _warnIfDebug
{
  my ($msg) = @_;
  if (EBox::Config::configkey('debug') eq 'yes') {
    EBox::warn($msg);
  }
}

# Method: escapeAddress
#
# escapes a network address to a represetation without problematic symbols
#
#  Parameters:
#    addr - unescaped source address
#
#  Returns:
#     escaped address
#
# Note: 
#    the problematic character is ':' for rrdtool. Other option would be to
#    take care to escape the address in rrdtool's invokations
sub escapeAddress
{
  my ($addr) = @_;
  $addr =~ s{:}{S}g;
  return $addr;
}

# Method: unescapeAddress
#
# unescapes the network address back to his real shape
#
#  Parameters:
#    addr - escaped source address
#
#  Returns:
#     unescaped address
sub unescapeAddress
{
  my ($addr) = @_;
  $addr =~ s{S}{:}g;
  return $addr;
}


sub _activeRRDs
{
  my ($rrds_r) = @_;

  my $now = time();
  my $threshold = $now -  RRD_TTL;

  my @active;
  foreach my $rrd (@{ $rrds_r }) {
    my $lastUpdate = RRDs::last($rrd);
    my $err        = RRDs::error;
    if ($err) {
      EBox::error("Error getting last update time of RRD $rrd: $err");
      next;
    }

    if ($lastUpdate < $threshold ) {
      _removeRRD($rrd);
      next;
    }

    push @active, $rrd;
  }

  return \@active;
}



sub _removeRRD
{
  my ($rrd) = @_;

  unlink $rrd;

  # XXX rework this, only works for sources
  # remove related RRDs
  my $dir  = _rrdDir();
  my $relatedGlob = basename $rrd;
  $relatedGlob =~ s{\.rrd$}{};
  $relatedGlob = "$dir/*" . $relatedGlob . '*.rrd';
  
  my @relatedFiles = bsd_glob($relatedGlob);
  foreach (@relatedFiles) {
    unlink $_;
  }
}



#  Method: activeServiceRRDs
#
#    return all the active service RRRDs 
#
#   Returns:
#     reference to list of all service RRDs
#
# Warning: 
#  this function cleans up all the inactive service RRDs (hence the
#  'active' in the name)
#
# XXX TODO the inactive RRDs cleanup should be done independently of this function
sub activeServiceRRDs
{
  my $dir = _rrdDir();
  my @rrds = bsd_glob("$dir/service-*.rrd");
  @rrds = @{ _activeRRDs(\@rrds) };

  return \@rrds;
}

#  Method: activeSrcsRRDs
#
#    return all the active sources RRRDs 
#
#   Returns:
#     reference to list of all sources RRDs
#
# Warning: 
#  this function cleans up all the inactive sources RRDs (hence the
#  'active' in the name)
#
# XXX TODO the inactive RRDs cleanup should be done independently of this function
sub activeSrcRRDs
{
  my $dir = _rrdDir();
  my @rrds = bsd_glob("$dir/src-*.rrd");
  @rrds = grep {
    not ($_ =~ m/-service-/)  # discard rrds of src + service aggregation
  } @rrds;

  @rrds = @{ _activeRRDs(\@rrds) };

  return \@rrds;
}


# XXX TODO separate graph functions to another package

# XXX add params validation

# Method: graph
#
#   make a traffic rate  graph
#
#   Parameters:
#      startTime - start time for the graphic (in seconds)
#      title     - graph's title
#      file      - file path for the graph image
#      dataset - dataset for the graphic, must be a reference to a list of hashes
#          each element must have the following fields:
#                   rrd - rrd file to extract the byte per seconds data
#                   colour - colour for the element's line
#                   legend - legend for the element
#
#      - Named parameters
sub graph
{
  my %params = @_;

  my @dataset   = @{ $params{dataset} };
  my $startTime = $params{startTime};
  my $title     = $params{title};

  my $file      = $params{file};

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
              '-w ' . GRAPH_WIDTH,
              '-h ' . GRAPH_HEIGHT,
	      @defs,
	      @lines,
	     );

  my $error = RRDs::error;
  if ($error) {
    throw EBox::Exceptions::Internal("rrdgraph error: $error");
  }
}

# Method: srcGraph
#
#      Given a source, it will ask to rrdtools to create a graph with
#      that source
#
# Parameters:
#
#      startTime - start time for the graphic (in seconds)
#      file      - file path for the graph image
#      src - String the source IP address (escaped)
#
#      - Named parameters
#
sub srcGraph
{
  my (%params) = @_;

  my $src = delete $params{src};
  if (not $src) {
    throw EBox::Exceptions::MissingArgument('src');
  }

  my $printableSrc = unescapeAddress($src);

  my $rrd = srcRRD($src);
  if (not -f $rrd) {
    throw EBox::Exceptions::DataNotFound(
					 data => __('Traffic data for source'),
					 value => $printableSrc,
                                        );
  }

  my $dataset = [
		 _srcDatasetElement($src, $rrd),
		];

  my @services = @{ srcServicesRRD($src) };
  my @colours = @{ EBox::ColourRange::range(scalar @services) };
  for ( my $idx; $idx < @services; $idx++) {
      my $serv = $services[$idx];
      my $srcAndServRRD = srcAndServiceRRD( $src, $serv );
      my $newDataset = _srcAndServiceDatasetElement($src, $serv, $srcAndServRRD, 1);
      my $colour = $colours[$idx];
      $newDataset->{colour} = $colour;
      push( @{$dataset}, $newDataset );
  }

  my $title =__x('Network traffic from {src}', src => $printableSrc);

  graph(
	dataset => $dataset,
	title   => $title,
	%params,
       );
}

# Method: serviceGraph
#
#      Given a service, it will ask to rrdtools to create a graph with
#      that service
#
# Parameters:
#
#      startTime - start time for the graphic (in seconds)
#      file      - file path for the graph image
#      service - String the service name
#
#      - Named parameters
#
sub serviceGraph
{
  my (%params) = @_;

  my $service = delete $params{service};
  if (not $service) {
    throw EBox::Exceptions::MissingArgument('service');
  }

  my $rrd = serviceRRD($service);
  if (not -f $rrd) {
    throw EBox::Exceptions::DataNotFound( 
           data => __( 'Traffic data not found for service'),
	   value => $service,
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

# Method: srcAndServiceGraph
#
#      Given a source and service pair, it will ask to rrdtools to create a graph
#      for this combination
#
# Parameters:
#
#      startTime - start time for the graphic (in seconds)
#      file      - file path for the graph image
#      src - String the source IP address (escaped)
#      service - String the service name
#
#      - Named parameters
#
sub srcAndServiceGraph
{
  my (%params) = @_;

  my $src     = delete $params{src};
  if (not $src) {
    throw EBox::Exceptions::MissingArgument('src');
  }

  my $service = delete $params{service};
  if (not $service) {
    throw EBox::Exceptions::MissingArgument('service');
  }

  my $printableSrc = unescapeAddress($src);

  my $srcRRD = srcRRD($src);
  if (not -f $srcRRD) {
    throw EBox::Exceptions::DataNotFound( 
					 data  => __('Traffic data for source'),
					 value => $printableSrc,
				    );
  }

  my $serviceRRD  = serviceRRD($service);  
  if (not -f $serviceRRD) {
    throw EBox::Exceptions::DataNotFound(
				     data => __( 'Traffic data for service'),
				     value => $service,
					);
  }

  my $srcAndServiceRRD = srcAndServiceRRD($src, $service);
  if (not -f $srcAndServiceRRD) {
    throw EBox::Exceptions::DataNotFound( 
				     data =>
				     __( 'Traffic data not found for source and service pair'),
				     value => __x(
						  'source {src} and service {service}',
						  src     => $printableSrc,
						  service => $service,
						 )
				     );
  }

  my $dataset = [
		 _srcDatasetElement($src, $srcRRD),
		 _serviceDatasetElement($service, $serviceRRD),
		 _srcAndServiceDatasetElement($src, $service, $srcAndServiceRRD, 0),
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

# Method: activeServicesGraph
#
#    creates a graphic with all the active services
#
# Parameters:
#
#      startTime - start time for the graphic (in seconds)
#      file      - file path for the graph image
#
#      - Named parameters
#
sub activeServicesGraph
{
  my %params = @_;

  my $title = __('All active services');

  my @services = @{  activeServiceRRDs()  };  
  @services or
    throw EBox::Exceptions::DataNotFound(
					 data => __('Traffic data for '),
					 value => __('all services'),
				    );

  my @colours = @{ EBox::ColourRange::range(scalar @services) };

  my @dataset;
  foreach my $service (@services) {
    # extract service name
    $service =~ m/service-(.*)\.rrd/;
    my $legend = $1;
    # Change tcp100 for tcp/100
    if ( $legend =~ m:\D\d: ) {
        $legend =~ s:(\D)(\d):$1/$2:;
    }
    my $ds = {
	      rrd     => $service,
	      legend => $legend,
	      colour => pop @colours,
	     };
    
    push @dataset, $ds;
  }
  
  graph(
	dataset => \@dataset,
	title   => $title,
	%params,
     );
}

# Method: activeSrcsGraph
#
#    creates a graphic with all the active sources
#
# Parameters:
#
#      startTime - start time for the graphic (in seconds)
#      file      - file path for the graph image
#
#      - Named parameters
#
sub activeSrcsGraph
{
  my %params = @_;

  my $title = __('All active sources');

  my @srcs = @{  activeSrcRRDs()  };  
  @srcs or
    throw EBox::Exceptions::DataNotFound(
				     data => __('Traffic data for'),
				     value => __('all sources')
				    );

  my @dataset;
  if (@srcs) {
      my @colours = @{ EBox::ColourRange::range(scalar @srcs) };

      foreach my $src (@srcs) {
	# extract src name
	$src =~ m/src-(.*)\.rrd/;
	my $legend = unescapeAddress($1);
	my $ds = {
		  rrd     => $src,
		  legend => $legend,
		  colour => pop @colours,
		 };
	
	push @dataset, $ds;
      }

      
      graph(
	    dataset => \@dataset,
	    title   => $title,
	    %params,
	   );
  }


  

}

sub _srcDatasetElement
{
  my ($src, $rrd) = @_;
  my $printableSrc = unescapeAddress($src);

  my $legend = __x("Total traffic rate from {src}", src => $printableSrc);

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

  my $legend = __x("Total traffic rate for {service}", service => $service);

  my $ds = {
	  rrd => $rrd,
	  legend => $legend,
	  colour => SERVICE_COLOUR,
	 };

  return $ds;
}

sub _srcAndServiceDatasetElement
{
  my ($src, $service, $rrd, $isSrcGraph) = @_;

  my $printableSrc = unescapeAddress($src);
  my $legend;
  if ( $isSrcGraph ) {
      $legend = $service;
      # Change tcp100 for tcp/100
      if ( $legend =~ m:\D\d: ) {
          $legend =~ s:(\D)(\d):$1/$2:;
      }
  } else {
      $legend = __x("Traffic rate from {src} for {service}", 
                    src     => $printableSrc,
                    service => $service,
                   );
  }

  my $ds = {
	  rrd => $rrd,
	  legend => $legend,
	  colour => SRC_AND_SERVICE_COLOUR,
	 };

  return $ds;
}


1;
