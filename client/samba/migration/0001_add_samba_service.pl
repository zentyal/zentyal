#!/usr/bin/perl


package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
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


sub _addSambaService
{

  my $global = EBox::Global->instance();
  my $fw = $global->modInstance('firewall');

  my $serviceMod = EBox::Global->modInstance('services');

  if (not $serviceMod->serviceExists('name' => 'samba')) {
    my @services;
    for my $port (qw(137 138 139 445)) {
      push (@services, { 'protocol' => 'tcp/udp', 
			 'sourcePort' => 'any',
			 'destinationPort' => $port });
    }
    $serviceMod->addMultipleService(
				    'name' => 'samba', 
				    'internal' => 1,
				    'description' =>  __d('File sharing (Samba) protocol'),
				    'translationDomain' => 'ebox-samba',
				    'services' => \@services);

    $serviceMod->saveConfig();

  } else {
    EBox::info("Not adding samba service as it already exists");
  }

  $fw->setInternalService('samba', 'accept');


  $fw->saveConfig();

}



sub runGConf
{
  my ($self) = @_;

  $self->_addSambaService();
}

EBox::init();

my $sambaMod = EBox::Global->modInstance('samba');
my $migration =  __PACKAGE__->new( 
    'gconfmodule' => $sambaMod,
    'version' => 1
);
$migration->execute();
