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
	[qw(service create name subnet subnetNetmask port proto  serverCertificate )];
    }
    else {
	return [];
    }

}


sub optionalParameters
{
    my ($self) = @_;
    if ($self->param('create')) {
	[qw(local clientToClient service)];
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

    return [
	    availableCertificates => $openvpn->availableCertificates(),
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

	while (my ($key, $value) = each %params) {
	    next if $value ne '';
	    delete $params{$key};
	}

    
	$self->setMsg(__x("New server {name} created", name => $name) );
	$self->{redirect} = 'OpenVPN/Index';
    }
}




1;

