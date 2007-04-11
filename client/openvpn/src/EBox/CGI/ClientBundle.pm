package EBox::CGI::OpenVPN::ClientBundle;
# Description:
use strict;
use warnings;
use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
use EBox::OpenVPN;
use EBox::OpenVPN::Server::ClientBundleGenerator;
use EBox::CA;
use File::Basename;
use Error qw(:try);


sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('OpenVPN'),
				      'template' => '/openvpn/clientBundle.mas',
				      @_);

	$self->{domain} = 'ebox-openvpn';
	bless($self, $class);
	return $self;
}


sub requiredParameters
{
    my ($self) = @_;
    return ['name'];
}


sub optionalParameters
{
    my ($self) = @_;
    # we use unsafeParam because download is free text and we don't use the value; only we check if the param is present
    if ($self->unsafeParam('download')) {
	[qw(download os clientCertificate ip\d+)];
    }
    else {
	return [];
    }
}


sub masonParameters
{
    my ($self) = @_;

    my $ca = EBox::Global->modInstance('ca');
    my $disabled = $ca->isCreated ? 0 : 1;

    my $openvpn    = EBox::Global->modInstance('openvpn');
    my $serverName = $self->param('name');
    my $serverCert = $openvpn->server($serverName)->certificate();

    my @clientCertificates = grep { $_ ne $serverCert  } @{ $openvpn->availableCertificates() };


    my $addresses;
    try {
      $addresses = $self->_serverAddresses();
    }
    otherwise {
      $addresses = [];
    };


    return [
	    name                  => $serverName,
	    disabled              => $disabled,
	    availableCertificates => \@clientCertificates,
	    addresses             =>  $addresses,
	   ];
}

sub _serverAddresses
{
  my ($self) = @_;

  my $openvpn    = EBox::Global->modInstance('openvpn');
  my $serverName = $self->param('name');
  my $server     = $openvpn->server($serverName);
  defined $server or throw EBox::Exceptions::Internal("Server $serverName does not exist");
  
  my $addrs = $self->_addressesFromParams();

  if (@{ $addrs  } == 0) {
    $addrs = EBox::OpenVPN::Server::ClientBundleGenerator->serversAddr($server);
  }

  return $addrs;
}

sub _addressesFromParams
{
  my ($self) = @_;
  my @addrs;

  my @params = @{ $self->params() };
  foreach my $param (@params) {
    EBox::debug("param $param");
    if ($param =~ m/^ip\d+$/) {
      my $addr = $self->param($param);
      EBox::debug("param $param=$addr");
      if ($addr) {
	push @addrs, $addr;
      }

    } 
  }

  EBox::debug("addrs @addrs");
  return \@addrs;
}

sub actuate
{
    my ($self) = @_;
 
    # we use unsafeParam because download is free text and we don't use the value; only we check if the param is present
    if ($self->unsafeParam('download')) {
	my $openvpn = EBox::Global->modInstance('openvpn');

	my $name              = $self->param('name');
	my $os                = $self->param('os');
	my $clientCertificate = $self->param('clientCertificate');
	my $addresses         = $self->_addressesFromParams();

	my $bundle;
	try {
	  $bundle = $openvpn->server($name)->clientBundle($os, $clientCertificate, $addresses);
	
	  $self->{bundle} = $bundle;
	}
        otherwise {
	  my $ex = shift;
	  $bundle->destructor() if defined $bundle;
	  $ex->throw();
	};
	
    }
}


sub _print
{
  my $self = shift;
  if ($self->{error} || not defined($self->{bundle})) {
    $self->SUPER::_print;
    return;
  }

  my $bundle = $self->{bundle};


 try {
   my $file = $bundle->{file};
   my $fileName = basename $file;

   open(my $FH,$file) or throw EBox::Exceptions::Internal('Could not open bundle file.');
   
   print($self->cgi()->header(-type       =>'application/octet-stream',
			      -attachment => $fileName));
   while (<$FH>) {
     print $_;
   }
   
   close $FH;
  }
  finally {
    $bundle->{destructor}->();
 };
}



1;

