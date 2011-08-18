# Copyright (C) 2008-2010 eBox Technologies S.L.
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

package EBox::RemoteServices::Base;

# Class: EBox::RemoteServices::Base
#
#       This could be applied as the base class to inherit from when a
#       connection with a remote service is done
#

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::RemoteServices::SOAPClient;
use EBox::Config;

use Date::Calc::Object;
use Error qw(:try);
use Net::DNS;

# Constants
use constant SRV_CONF_FILE => '78remoteservices.conf';

# Group: Public methods

# Constructor: new
#
#     Creates a new client connection object
#
# Returns:
#
#     <EBox::RemoteServices::Base> - the recently created object
#
sub new
{
  my ($class, %params) = @_;


  my $self = {};

  bless($self, $class);
  return $self;
}

# Method: connection
#
#     Accessor to the connection among server and client.
#
#     It establishes the connection (service-oriented one) if it is
#     not ready yet
#
# Returns:
#
#     <EBox::RemoteServices::SOAPClient> - the connection
#
sub connection
{
    my ($self) = @_;

    unless (exists $self->{connection}) {
        $self->_connect();
    }
    return $self->{connection};
}

# Method: soapCall
#
#     Call a method/procedure through the opened web service given its
#     urn and the proxy server to ask. To be overriden by subclasses
#
# Parameters:
#
#     method - String the method's name to call
#
#     params - array the parameters from that method
#
# Returns:
#
#     Whatever the remote method/procedure returns back
#
sub soapCall
{
    throw EBox::Exceptions::NotImplemented();
}

# FIXME: Doc
sub remoteServicesActive
{
  return 1;
}

# Group: Public static methods

# Method: serviceUrn
#
#     Accessor to the service to ask for unified resource name. To be
#     overriden by subclasses
#
# Returns:
#
#     String - the unified resource name
#
sub serviceUrn
{
  throw EBox::Exceptions::NotImplemented();
}

# Method: serviceHostName
#
#     Accessor to the proxy server which contains the desired service.
#     To be overriden by subclasses
#
# Returns:
#
#     String - the hostname
#
sub serviceHostName
{
    throw EBox::Exceptions::NotImplemented();
}

# Group: Protected methods

# Method: _connect
#
#      Establish the connection between the client and the server. If
#      you need to override it, don't forget to call this parent
#      method firstly.
#
sub _connect
{
    my ($self) = @_;
    $self->_soapConnect();
}

# Method: _disconnect
#
#      Erase the establish connection, done by
#      <EBox::RemoteServices::Base::_connect> method.
#
sub _disconnect
{
  my ($self) = @_;
  delete $self->{connection};
}

# Method: _urlSuffix
#
#      Suffix to add to the request in HTTP proxy. Current request
#      will be done to:
#
#      https://<ipAddress>/soap/<urlSuffix>
#
# Returns:
#
#      String - the url suffix to add to the request. Default value:
#      empty string
#
sub _urlSuffix
{
    return '';
}

# Method: _nameservers
#
#       Return the name server from a configuration file
#
# Returns:
#
#       Array ref - containing the IP addresses for the name servers
#
sub _nameservers
{
    my ($self) = @_;

    my $eboxServicesDns =  EBox::Config::configkeyFromFile('ebox_services_nameserver',
                                                           EBox::Config::etc() . SRV_CONF_FILE);
    unless ($eboxServicesDns) {
        throw EBox::Exceptions::External(
            __('No ebox-services DNS key found')
           );
    }

    my @nameservers = split(',', $eboxServicesDns);
    # add system nameservers 
    my $network = EBox::Global->modInstance('network');
    push @nameservers, @{ $network->nameservers() };

    return \@nameservers;
}

# Method: _queryServicesNameserver
#
#       Query an A record to the internal name servers.
#
#       Internal name servers are defined by <_nameservers> method
#
#
# Parameters:
#
#       hostname - String the host name to query
#
#       nameservers - Array ref the nameservers to ask
#                     *(Optional)* Default value: <_nameservers> returned value
#
# Returns:
#
#       String - the mapped IP address for this name by the internal
#       name servers. If there are more than one a naive load
#       balancing scheme is done (choose one of them randomly)
#
sub _queryServicesNameserver
{
    my ($self, $hostname, $nameservers) = @_;

    $nameservers = $self->_nameservers() unless (defined($nameservers));

    my $resolver = Net::DNS::Resolver->new(
          nameservers => $nameservers,
          defnames    => 0, # no default domain
          udp_timeout => 15, # 15 s. prior to timeout
    );

    my $response = $resolver->query($hostname);
    if (not defined $response) {
        throw EBox::Exceptions::External(
            __x(
                'Server {s} not found via DNS server {d}. Reason: {r}',
                'd' => join(',', @{$nameservers}),
                's' => $hostname,
                'r' => $resolver->errorstring(),
               )
           )
    }

    my @addresses =  map { $_->address() } (grep { $_->type() eq 'A' } $response->answer());

    # Round-robin balancing
    my $n = int(rand(scalar @addresses));
    my $address = $addresses[$n];

    return $address;
}

# Method: _printableSize
#
#    Given a size in Bytes, transform to a string using KB, MB or GB
#
# Parameters:
#
#    size - Int the size in Bytes
#
# Returns:
#
#    String - the size in KB, MB or GB including the measure at the
#    end of the string
#
# Example:
#
#    1024 -> 1 KB
#
sub _printableSize
{
    my ($self, $size) = @_;

    my @units = qw(KB MB GB);
    foreach my $unit (@units) {
        $size = sprintf ("%.2f", $size / 1024);
        if ($size < 1024) {
            return "$size $unit";
        }
    }

    return $size . ' ' . (pop @units);
}


# Method: _sortableDate
#
#      Given a date in String format, try to transform to a sortable
#      date using seconds from epoch
#
# Parameters:
#
#      date - String the date in string format
#
# Returns:
#
#      Int - the seconds since epoch using the given date as parameter
#
sub _sortableDate
{
    my ($self, $dateStr) = @_;

    my ($strDay, $day, $monthStr, $year, $h, $m, $s) =
      $dateStr =~ m/^([A-Za-z]{3}), ([0-9]{2}) ([A-Za-z]{3}) ([0-9]{4}) ([0-9]{2}):([0-9]{2}):([0-9]{2}).*$/;
    my $date = new Date::Calc( $year, Date::Calc::Decode_Month($monthStr), $day,
                               $h, $m, $s);
    return $date->mktime();

}

# Group: Private methods

sub _soapConnect
{
    my ($self) = @_;

    my $urn    = 'urn:' . $self->serviceUrn();
    my $server = 'https://' . $self->_servicesServer() . '/soap'
      . $self->_urlSuffix();


    my %certificates = (
        ca   => $self->{caCertificate},
        cert => $self->{certificate},
        private => $self->{certificateKey},
       );

    my $soapClient;
      if ( not defined($certificates{ca})) {
          $soapClient = EBox::RemoteServices::SOAPClient->instance(
              name => $urn,
              proxy => $server,
             );
      } else {
          $soapClient = EBox::RemoteServices::SOAPClient->instance(
              name => $urn,
              proxy => $server,
              certs => \%certificates,
             );
      }

    defined $soapClient or
      throw EBox::Exceptions::External(
          __('Cannot create SOAP connection')
         );


    $self->{connection} = $soapClient;
}

sub _servicesServer
{
  my ($self) = @_;

  my $serviceHostName = $self->serviceHostName();
  $serviceHostName or
    throw EBox::Exceptions::External(
                 __('No domain key found for this service')
				    );
  return $self->_queryServicesNameserver($serviceHostName);
}


# Check given host and port is reachable using nmap tool
sub _checkHostPort
{
    my ($self, $host, $proto, $port) = @_;
    $proto = lc $proto;

    my $res = EBox::Util::Nmap::singlePortScan(host => $host,
                                               protocol => $proto,
                                               port => $port,
                                               );
    if ($res eq 'open') {
        return 1;
    }

    if (($proto eq 'udp') ) {
        # in UDP packets this could be open or not. We treat this as open to
        # avoid false negatives (but we will have false positives)
        if (($res eq 'open/filtered') or ($res eq 'filtered')) {
            return 1;
        } else {
            return 0;
        }

    }
    return 0;
}

1;
