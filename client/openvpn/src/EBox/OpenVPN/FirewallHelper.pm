package EBox::OpenVPN::FirewallHelper;
use base 'EBox::FirewallHelper';
# Description:
use strict;
use warnings;


sub new 
{
        my ($class, %opts) = @_;

        my $self = $class->SUPER::new(%opts);
	$self->{service}          =  delete $opts{service};
	$self->{portsByProto}     =  delete $opts{portsByProto};
	$self->{serversToConnect} =  delete $opts{serversToConnect};

        bless($self, $class);
        return $self;
}


sub service
{
    my ($self) = @_;
    return $self->{service};
}


sub portsByProto
{
    my ($self) = @_;
    return $self->{portsByProto};
}

sub serversToConnect
{
    my ($self) = @_;
    return $self->{serversToConnect};
}

sub externalInput
{
    my ($self) = @_;
    my @rules;

    $self->service() or return [];


    my $portsByProto = $self->portsByProto;
    foreach my $proto (keys %{$portsByProto}) {
	my @ports = @{ $portsByProto->{$proto} };
	foreach my $port (@ports) {
	    my $rule = "--protocol $proto --destination-port $port -j ACCEPT";
	    push @rules, $rule;
	}
    }


    return \@rules;
}

sub output
{
    my ($self) = @_;
    my @rules;

    if ($self->service()) {
    
      foreach my $server_r (@{ $self->serversToConnect() }) {
	my ($serverProto, $server, $serverPort) = @{ $server_r };
	my $connectRule =  "--protocol $serverProto --destination $server --destination-port $serverPort -j ACCEPT";
	push @rules, $connectRule;
      }
    }


    # we need HTTP access for client bundle generation (need to resolve external address)
    my $httpRule = "--protocol tcp  --destination-port 80 -j ACCEPT";
    push @rules, $httpRule;

    return \@rules;
}





1;
