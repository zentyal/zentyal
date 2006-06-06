package EBox::OpenVPN::FirewallHelper;
use base 'EBox::FirewallHelper';
# Description:
use strict;
use warnings;

sub new 
{
        my ($class, %opts) = @_;
	my $ports_r = delete $opts{portsByProto};

        my $self = $class->SUPER::new(%opts);
	$self->{portsByProto} = $ports_r;

        bless($self, $class);
        return $self;
}


sub portsByProto
{
    my ($self) = @_;
    return $self->{portsByProto};
}



sub input
{
    my ($self) = @_;

    my @rules = ('-i tun+ -j ACCEPT'); # do not firewall openvpn virtual iface

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
    my @rules = ('-i tun+ -j ACCEPT'); # do not firewall openvpn virtual iface
    
    my $portsByProto = $self->portsByProto;
    foreach my $proto (keys %{$portsByProto}) {
	my @ports = @{ $portsByProto->{$proto} };
	foreach my $port (@ports) {
	    my $rule = "--protocol $proto --source-port $port -j ACCEPT";
	    push @rules, $rule;
	}
    }

    return \@rules;
}


sub forward
{
    my ($self) = @_;
    my @rules = ('-i tun+ -j ACCEPT'); # do not firewall openvpn virtual iface
    return \@rules;
}


1;
