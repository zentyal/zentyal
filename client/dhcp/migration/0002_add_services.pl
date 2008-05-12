#!/usr/bin/perl


package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;



use EBox;
use EBox::Global;
use EBox::Gettext;
use Data::Dumper;
use EBox::Model::ModelManager;
use Socket;
use Error qw(:try);


# XXX remove when this block is included in EBox::MigrationBase

# Method: addInternalService
#
#  Helper method to add new internal services to the service module and related
#  firewall rules
#
#
#  Named Parameters:
#    name - name of the service
#    protocol - protocol used by the service
#    sourcePort - source port used by the service (default : any)
#    destinationPort - destination port used by the service (default : any)
#    target - target for the firewall rule (default: allow)
sub addInternalService
{
  my ($self, %params) = @_;
  exists $params{name} or
    throw EBox::Exceptions::MissingArgument('name');

  $self->_addService(%params);

  my @fwRuleParams = ($params{name});
  push @fwRuleParams, $params{target} if exists $params{target};
  $self->fwRuleForInternalService(@fwRuleParams);
}

sub fwRuleForInternalService
{
  my ($self, $service, $target) = @_;
  $service or
    throw EBox::Exceptions::MissingArgument('service');
  $target or
    $target = 'accept';

  my $fw = EBox::Global->modInstance('firewall');
  $fw->setInternalService($service, $target);
  $fw->saveConfigRecursive();
}

sub _addService
{
  my ($self, %params) = @_;
  exists $params{name} or
    throw EBox::Exceptions::MissingArgument('name');
  exists $params{protocol} or
    throw EBox::Exceptions::MissingArgument('protocol');
  exists $params{sourcePort} or
    $params{sourcePort} = 'any';
  exists $params{destinationPort} or
    $params{destinationPort} = 'any';

  my $serviceMod = EBox::Global->modInstance('services');

  if (not $serviceMod->serviceExists('name' => $params{name})) {
    $serviceMod->addService('name' => $params{name},
			    'protocol' => $params{protocol},
			    'sourcePort' => $params{sourcePort},
			    'destinationPort' => $params{destinationPort},
			    'internal' => 1,
			    'readOnly' => 1
			   );
    
  } else {
    $serviceMod->setService('name' => $params{name},
			    'protocol' => $params{protocol},
			    'sourcePort' => $params{sourcePort},
			    'destinationPort' => $params{destinationPort},
                            'internal' => 1,
			    'readOnly' => 1);
    
    EBox::info("Not adding $params{name} service as it already exists instead");
  }

    $serviceMod->saveConfig();
}

# XXX END OF BLOCK


sub _createUserConfDir
{
  my ($self) = @_;

  my $dhcp = $self->{gconfmodule};
  
  my $dir = $dhcp->userConfDir();
  mkdir ($dir, 0755);
}

sub runGConf
{
  my ($self) = @_;

  $self->addInternalService(
			    'name' => 'tftp',
			    'description' => __d('Trivial File Transfer Protocol'),
			    'translationDomain' => 'ebox-dhcp',
			    'protocol' => 'udp',
			    'sourcePort' => 'any',
			    'destinationPort' => 69,
			   );

  $self->addInternalService(
			    'name' => 'dhcp',
			    'description' => __d('Dynamic Host Configuration Protocol'),
			    'translationDomain' => 'ebox-dhcp',
			    'protocol' => 'udp',
			    'sourcePort' => 'any',
			    'destinationPort' => 67,
			   );
  
  $self->_createUserConfDir();
}

EBox::init();

my $dhcpMod = EBox::Global->modInstance('dhcp');
my $migration =  __PACKAGE__->new( 
    'gconfmodule' => $dhcpMod,
    'version' => 2
);
$migration->execute();
