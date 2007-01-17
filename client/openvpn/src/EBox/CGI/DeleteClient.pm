package EBox::CGI::OpenVPN::DeleteClient;
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
				      'template' => '/openvpn/delete.mas',
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
    return ['deleteConfirmed', 'cancel'];
}




sub masonParameters
{
    my ($self) = @_;

    my $name = $self->param('name');
    my $type = __('Client');
    return [name => $name, type => $type, action => 'DeleteClient'];
}



sub actuate
{
    my ($self) = @_;

    if ($self->param('cancel')) {
	$self->{redirect} = 'OpenVPN/Index';
    }
    elsif ($self->param('deleteConfirmed')) {
	$self->_doDelete();
	$self->{redirect} = 'OpenVPN/Index';
    }
}




sub _doDelete
{
    my ($self) = @_;

    my $name = $self->param('name');
    my $openVPN = EBox::Global->modInstance('openvpn');
    $openVPN->removeClient($name);

    $self->setMsg(__x("Client {name} removed", name => $name) );
 }

1;

