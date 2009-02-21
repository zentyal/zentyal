package EBox::AntiVirus::FirewallHelper;
#
use strict;
use warnings;

use base 'EBox::FirewallHelper';

sub new 
{
    my ($class, %params) = @_;
    my $self = $class->SUPER::new(%params);

    bless($self, $class);
    return $self;
}

sub output
{
    my ($self) = @_;
    my @rules;

    # freshclam update service
    push (@rules, '--protocol tcp --dport 80 -j ACCEPT');

    return \@rules;
}

1;
