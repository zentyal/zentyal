package EBox::CGI::OpenVPN::ClientBundle;
# Description:
use strict;
use warnings;
use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
use EBox::OpenVPN;
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
    if ($self->param('download')) {
	[qw(download os clientCertificate )];
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

    return [
	    name                  => $serverName,
	    disabled              => $disabled,
	    availableCertificates => \@clientCertificates,
	   ];
}

sub actuate
{
    my ($self) = @_;
 
    if ($self->param('download')) {
	my $openvpn = EBox::Global->modInstance('openvpn');

	my $name              = $self->param('name');
	my $os                = $self->param('os');
	my $clientCertificate = $self->param('clientCertificate');

	my $bundle;
	try {
	  $bundle = $openvpn->server($name)->clientBundle($os, $clientCertificate);
	
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

