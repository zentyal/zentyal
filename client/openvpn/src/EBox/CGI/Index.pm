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

    my @servers = $openVPN->serversNames();
    my @clients = $openVPN->userClientsNames();
    
    my $noCA = $openVPN->CAIsReady() ? 0 : 1;

    return [ 
	    servers => \@servers, 
	    clients => \@clients, 
	    noCA => $noCA,  
	   ];
}

sub actuate
{
  my ($self) = @_;

}




1;
