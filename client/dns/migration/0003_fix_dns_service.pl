#!/usr/bin/perl


package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Error qw(:try);




sub runGConf
{
  my ($self) = @_;

  my $serviceMod = EBox::Global->modInstance('services');
  my $id = $serviceMod->serviceId('dns');
  if (not defined $id) {
      EBox::info("No dns service, nothing to migrate");
      return;
  }

  my @serviceConf = @{ $serviceMod->serviceConfiguration($id) };
  if (@serviceConf != 1) {
      return;
  }

  my ($conf) = @serviceConf;
  # check that is the conf setted by the previous default values...
  ($conf->{protocol} eq 'udp') or
      return;
  ($conf->{source} eq 'any') or
      return;
  ($conf->{destination}  == 53) or
      return;


  my $serviceRow = $serviceMod->{serviceModel}->row($id);
  my $configuration = $serviceRow->elementByName('configuration')->foreignModelInstance();
  $configuration->addRow(
                         protocol => 'tcp',
                         source_range_type   => 'any',
                         destination_range_type => 'single',
                         destination_single_port => 53,
                        );

}

EBox::init();

my $dnsMod = EBox::Global->modInstance('dns');
my $migration =  __PACKAGE__->new(
    'gconfmodule' => $dnsMod,
    'version' => 3
);
$migration->execute();
