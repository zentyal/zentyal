package EBox::CGI::OpenVPN::Edit;
# Description:
use strict;
use warnings;
use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
use EBox::OpenVPN;
use Perl6::Junction qw(any);

my @serverProperties = qw(subnet subnetNetmask port proto certificate  clientToClient local service tlsRemote pullRoutes);
my @regularAccessorsAndMutators =  qw(port proto certificate  clientToClient local service tlsRemote pullRoutes);

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
 
    my @optional;

    # we add the parameters from the scripts which redirect here
    @optional = qw(name network netmask submit);

    if ($self->param('edit')) {
      push @optional, @serverProperties;
    }

    return \@optional;
}


sub masonParameters
{
    my ($self) = @_;

    

    my $name = $self->param('name');
    $name or throw EBox::Exceptions::External('No server name provided');

    my $openVPN = EBox::Global->modInstance('openvpn');
    my $server = $openVPN->server($name);

    my %serverAttributes;
    foreach my $attr (@serverProperties) {
	my $accessor_r = $server->can($attr);
	defined $accessor_r or throw EBox::Exceptions::Internal "Can not locate accessor for $attr in server class";
	my $value = $accessor_r->($server);
	$serverAttributes{$attr} = $value;
    }


    my @advertisedNets = $server->advertisedNets();

    
    my $disabled = $openVPN->CAIsReady() ? 0 : 1;
    
    my $availableCertificates;
    if (not $disabled) {
      $availableCertificates = $openVPN->availableCertificates();
    }
    else {
      $availableCertificates = [];
    }

    my $network = EBox::Global->modInstance('network');
    my $externalIfaces = $network->ExternalIfaces();

    return [
	    name => $name, 
	    serverAttrs => \%serverAttributes,
	    availableCertificates => $availableCertificates,
	    disabled              => $disabled,
	    localInterfaces       => $externalIfaces,
	    advertisedNets        => \@advertisedNets,	   
	   ];
}





sub actuate
{
  my ($self) = @_;

  # check if CA and a certificate is available
  my $openVPN = EBox::Global->modInstance('openvpn');
  $openVPN->CAIsReady() or return;

  # check if there are external nics available
  my $network = EBox::Global->modInstance('network');
  my $externalIfaces = $network->ExternalIfaces();
  @{ $externalIfaces } or return;

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

    my $anyPropertyParam = any @regularAccessorsAndMutators;
    my @mutatorsParams = grep { $_ eq $anyPropertyParam } @{ $self->params() };
    
    $changed = 1 if $self->_editSubnetAndMask();

    foreach my $attr (@mutatorsParams) {
	my $value = $self->param($attr);

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
	$self->{chain} = 'OpenVPN/Index';
    }
    else {
	$self->setMsg( __('There are no changes to be saved'));
    }
}


sub _editSubnetAndMask
{
  my ($self) = @_;

  my $name = $self->param('name');
  my $openVPN = EBox::Global->modInstance('openvpn');
  my $server = $openVPN->server($name);

  my $subnet = $self->param('subnet');
  my $subnetNetmask = $self->param('subnetNetmask');

  if (($subnet eq $server->subnet()) and ($subnetNetmask eq $server->subnetNetmask)) {
    return 0;
  }

  $server->setSubnetAndMask($subnet, $subnetNetmask);

  return 1;
}

1;

