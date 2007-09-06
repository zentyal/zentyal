package EBox::MailFilter::FirewallHelper;
#
use strict;
use warnings;

use base 'EBox::FirewallHelper';

use EBox::Exceptions::MissingArgument;

sub new 
{
  my ($class, %params) = @_;
  my $self = $class->SUPER::new(%params);

  my @paramNames = qw(active antivirusActive port externalMTAs fwport);
  foreach my $p (@paramNames) {
    exists $params{$p} or
      throw EBox::Exceptions::MissingArgument("$p");

    $self->{$p} = $params{$p};
  }

  bless($self, $class);
  return $self;
}



sub input
{
  my ($self) = @_;
  my @rules;

  if (not $self->{active}) {
    return [];
  }

  my @externalMTAs = @{ $self->{externalMTAs} };
  if (@externalMTAs ) {
    my $port = $self->{port};
    push @rules, "--protocol tcp --dport $port   -j ACCEPT";

  }

  return \@rules;
}


sub output
{
  my ($self) = @_;
  my @rules;

  if (not $self->{active}) {
    return [];
  }

  my @externalMTAs = @{ $self->{externalMTAs} };
  if (@externalMTAs) {
    my $fwport = $self->{fwport};
    push @rules, "--protocol tcp --dport $fwport -j ACCEPT";
  }

  if ($self->{antivirusActive}) {
    # freshclam update service
    push @rules, '--protocol tcp --dport 80 -j ACCEPT';
  }

  return \@rules;
}

1;
