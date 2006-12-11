package EBox::CGI::OpenVPN::Edit;
# Description:
use strict;
use warnings;
use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
use EBox::OpenVPN;
use Perl6::Junction qw(any);

my @serverPropierties = qw(subnet subnetNetmask port proto serverCertificate  clientToClient local service);

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('OpenVPN'),
				      'template' => '/openvpn/edit.mas',
				      @_);
	$self->{domain} = 'ebox-openvpn';
	bless($self, $class);
	return $self;
}


sub requiredParameters
{
    my ($self) = @_;
    if ($self->param('edit')) {
	return ['name', 'edit'];
    }
    else {
	return ['name'];
    }
}


sub optionalParameters
{
    my ($self) = @_;
    if ($self->param('edit')) {
	return \@serverPropierties;
    }
    else {
	return [];
    }
}


sub masonParameters
{
    my ($self) = @_;

    my $name = $self->param('name');
    my $openVPN = EBox::Global->modInstance('openvpn');
    my $server = $openVPN->server($name);

    my %serverAttributes;
    foreach my $attr (@serverPropierties) {
	my $accessor_r = $server->can($attr);
	defined $accessor_r or throw EBox::Exceptions::Internal "Can not locate accessor for $attr in server class";
	my $value = $accessor_r->($server);
	$serverAttributes{$attr} = $value;
    }

    my $ca = EBox::Global->modInstance('ca');
    my $disabled = $ca->isCreated > 0 : 1;

    return [name => $name, 
	    serverAttrs => \%serverAttributes,
	    availableCertificates => $openVPN->availableCertificates()
	    disabled              => $disabled,
	   ];
}





sub actuate
{
    my ($self) = @_;
    if ($self->param('edit')) {
	$self->_doEdit();
    }

}


sub _doEdit
{
    my ($self) = @_;

    my $name = $self->param('name');
    my $openVPN = EBox::Global->modInstance('openvpn');
    my $server = $openVPN->server($name);
    my $changed = 0;

    my $anyPropiertyParam = any @serverPropierties;

    my @mutatorsParams = grep { $_ eq $anyPropiertyParam } @{ $self->params() };
    

    foreach my $attr (@mutatorsParams) {
	my $value = $self->param($attr);
	next if $value eq '';

	if ($server->$attr() ne $attr) {
	    my $mutatorName = "set\u$attr";
	    my $mutator_r   = $server->can($mutatorName);
	    defined $mutator_r or throw EBox::Exceptions::Internal "$mutatorName not found in server object";

	    $mutator_r->($server, $value);
	    $changed = 1;
	}
    }

    
    if ($changed) {
	$self->setMsg(__x("Server {name} configuration updated", name => $name) );
	$self->{redirect} = 'OpenVPN/Index';
    }
    else {
	$self->setMsg( __('There are no changes to be saved'));
    }
}



1;

