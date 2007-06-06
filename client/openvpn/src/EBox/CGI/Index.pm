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
	    'setService',
	    '.*', # XXX bad fix for optional  parameters in redirects. Remove in next iterattion
	   ];
}


sub masonParameters
{
    my ($self) = @_;
    my $openVPN = EBox::Global->modInstance('openvpn');
    my $service = $openVPN->service();
    my @servers = $openVPN->serversNames();
    my @clients = $openVPN->clientsNamesForUI();
    
    my $disabled = $openVPN->CAIsCreated() ? 0 : 1;

    return [ service => $service, servers => \@servers, clients => \@clients, disabled => $disabled  ];
}

sub actuate
{
  my ($self) = @_;
  my $openVPN = EBox::Global->modInstance('openvpn');

  $openVPN->CAIsCreated() or return;

  my $setServiceParam  = $self->param('setService');
  if ($setServiceParam ) {
    
    $openVPN->setService($setServiceParam);
    $self->setMsg(__("OpenVPN service status changed"));
  }

}




1;
