package EBox::CGI::OpenVPN::Create;
# Description:
use strict;
use warnings;
use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
use EBox::OpenVPN;
use EBox::CA;

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('OpenVPN'),
				      'template' => '/openvpn/create.mas',
				      @_);

	$self->{domain} = 'ebox-openvpn';
	bless($self, $class);
	return $self;
}


sub requiredParameters
{
    my ($self) = @_;
    if ($self->param('create')) {
	[qw(service create name subnet subnetNetmask port proto  certificate )];
    }
    else {
	return [];
    }

}


sub optionalParameters
{
    my ($self) = @_;
    if ($self->param('create')) {
	[qw(local clientToClient service advertisedNets tlsRemote pullRoutes)];
    }
    else {
	return [qw(createFromIndex)];
    }
}


sub masonParameters
{
    my ($self) = @_;

    my $ca = EBox::Global->modInstance('ca');
    my $disabled = $ca->isCreated ? 0 : 1;

    my $openvpn = EBox::Global->modInstance('openvpn');

    my $network = EBox::Global->modInstance('network');
    my $externalIfaces = $network->ExternalIfaces();

    return [
	    availableCertificates => $openvpn->availableCertificates(),
	    localInterfaces       => $externalIfaces,
	    disabled              => $disabled,
	   ];
}

sub actuate
{
    my ($self) = @_;
 
    if ($self->param('create')) {
	my $openVPN = EBox::Global->modInstance('openvpn');

	my %params = %{ $self->paramsAsHash() };
	my $name   = delete $params{name};

	# remove blank parameters
	while (my ($key, $value) = each %params) {
	    next if $value ne '';
	    delete $params{$key};
	}

	if (exists $params{tlsRemote} and !$params{tlsRemote}) {
	  delete $params{tlsRemote};
	}


	$params{internal} = 0; # servers created by UI aren't internal

	$openVPN->newServer($name, %params);

        my $cgiQuery = $self->{cgi};
	$cgiQuery->delete_all();   
	$cgiQuery->param(name => $name);
	$self->keepParam('name');

	$self->setMsg(
		      __x('New server {name} created. Now you can add advertised routes', 
			  name => $name
			 ) 
		     );


	$self->{chain} = 'OpenVPN/Edit';
    }
}




1;

