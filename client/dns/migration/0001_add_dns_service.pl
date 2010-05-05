#!/usr/bin/perl


package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Error qw(:try);

# XXX remove when this block is included in EBox::Migration::Base


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


# XXX END OF BLOCK


sub runGConf
{
  my ($self) = @_;

  my $serviceMod = EBox::Global->modInstance('services');

  if (not $serviceMod->serviceExists('name' => 'dns')) {
      $serviceMod->addMultipleService(
                                name => 'dns',
                                description => 'Domain Name Service',
                                services => [
                                             {
                                              'protocol' => 'udp',
                                              'sourcePort' => 'any',
                                              'destinationPort' => 53,
                                             },
                                             {
                                              'protocol' => 'tcp',
                                              'sourcePort' => 'any',
                                              'destinationPort' => 53,
                                             },
                                            ],

                               );
      $serviceMod->saveConfig();

  } else {
      EBox::info("Not adding DNS service as it already exists");      
  }


  $self->fwRuleForInternalService('dns');
}

EBox::init();

my $dnsMod = EBox::Global->modInstance('dns');
my $migration =  __PACKAGE__->new(
    'gconfmodule' => $dnsMod,
    'version' => 1
);
$migration->execute();
