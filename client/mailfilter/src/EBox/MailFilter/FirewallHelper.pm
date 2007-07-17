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

  exists $params{port} or 
    throw EBox::Exceptions::MissingArgument('port');
  exists $params{externalMTAs} or 
    throw EBox::Exceptions::MissingArgument('externalMTAs');
  exists $params{fwport} or 
    throw EBox::Exceptions::MissingArgument('fwport');

  $self->{port}         = $params{port};
  $self->{fwport}         = $params{fwport};
  $self->{externalMTAs} = $params{externalMTAs};

  bless($self, $class);
  return $self;
}



sub input
{
  my ($self) = @_;
  my @externalMTAs = @{ $self->{externalMTAs} };

  if (@externalMTAs == 0) {
    # no need from external connections
    return [];
  }


  my $port = $self->{port};


  return [
	  "--protocol tcp --dport $port   -j ACCEPT",
	 ];

}


sub output
{
  my ($self) = @_;
  my @externalMTAs = @{ $self->{externalMTAs} };

  if (@externalMTAs == 0) {
    # no need from external connections
    return [];
  }


  my $fwport = $self->{fwport};


  return [
	  "--protocol tcp --dport $fwport   -j ACCEPT",
	 ];

}

1;
