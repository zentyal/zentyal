package EBox::CGI::OpenVPN::Index;
# Description:
use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
use EBox::OpenVPN;


sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('OpenVPN'),
				      'template' => '/openvpn/index.mas',
				      @_);
	$self->{domain} = 'ebox-openvpn';
	bless($self, $class);
	return $self;
}

sub optionalParameters
{
    return [
	    'setService'
	   ];
}


sub masonParameters
{
    my ($self) = @_;
    my $openVPN = EBox::Global->modInstance('openvpn');
    my $service = $openVPN->service();
    my @servers = $openVPN->serversNames();

    my $ca = EBox::Global->modInstance('ca');
    my $disabled = $ca->isCreated ? 0 : 1;

    return [ service => $service, servers => \@servers, disabled => $disabled  ];
}

sub actuate
{
    my ($self) = @_;

    $self->_checkCA() or return;

    my $setServiceParam  = $self->param('setService');
    if ($setServiceParam ) {
	my $openVPN = EBox::Global->modInstance('openvpn');
	$openVPN->setService($setServiceParam);
	$self->setMsg(__("OpenVPN service status changed"));
    }

}



1;
