package EBox::MailFilter::FirewallHelper;
#
use strict;
use warnings;

use base 'EBox::FirewallHelper';

use EBox::Exceptions::MissingArgument;
use EBox::Global;

sub new 
{
  my ($class, %params) = @_;
  my $self = $class->SUPER::new(%params);

  my @paramNames = qw(smtpFilter antivirusActive port externalMTAs fwport 
                      POPProxy POPProxyPort
                   );
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

  if (not $self->{smtpFilter}) {
    return [];
  }

  my @externalMTAs = @{ $self->{externalMTAs} };
  if (@externalMTAs ) {
    my $port = $self->{port};
    push @rules, "--protocol tcp --dport $port   -j ACCEPT";

  }

  if ($self->{POPProxy}) {
      my $port = $self->{POPProxyPort};
      push @rules, "-m state --state NEW --protocol tcp --dport $port   -j ACCEPT";
  }

  return \@rules;
}


sub output
{
  my ($self) = @_;
  my @rules;

  if ($self->{smtpFilter}) {
      my @externalMTAs = @{ $self->{externalMTAs} };
      if (@externalMTAs) {
          my $fwport = $self->{fwport};
          push @rules, "--protocol tcp --dport $fwport -j ACCEPT";
      }
  }


  if ($self->{antivirusActive}) {
    # freshclam update service
    push @rules, '--protocol tcp --dport 80 -j ACCEPT';
  }

  return \@rules;
}

sub prerouting
{
    my ($self) = @_;


    # prerouting NAT is only used for POP transaprent proxy
    if (not $self->{POPProxy}) {
        return [];
    }

    # we will redirect all POP conenctions, which came from 
   # a internal interface (no POP proxy for external networks)
   # and that aren't  aimed to a local POP server
   # (we do not proxy ourselves)


    my @rules;

    my $popPort = 110;
    my $port = $self->{POPProxyPort};

    my $network = EBox::Global->modInstance('network');

    my @internals = @{ $network->InternalIfaces() };
    my @externals = @{ $network->ExternalIfaces()   };

    my @addrs = map {
      my @ifAddrs = map {
        $_->{address}
      } @{  $network->ifaceAddresses($_) }
    } (@internals, @externals);
    push @addrs, '127.0.0.1';



    foreach my $int (@internals) {
      foreach my $addr (@addrs) {
            push @rules,
                "-p tcp -i $int --destination  $addr  --dport $popPort -j RETURN";
      }
    }
    foreach my $int (@internals) {
        push @rules, "-p tcp -i $int --dport $popPort -j REDIRECT --to $port";  
    }

    return \@rules;
}


1;
