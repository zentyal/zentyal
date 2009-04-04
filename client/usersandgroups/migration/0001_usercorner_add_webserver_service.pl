#!/usr/bin/perl

package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Error qw(:try);

sub _availablePort
{
  my ($self) = @_;

  my $firewallMod = EBox::Global->modInstance('firewall');

  my $port = 8888; # Default port = 8888

  # Check port availability
  my $available = 0;
  do {
   $available = $firewallMod->availablePort('tcp', $port);
    $available = 1;
    unless ( $available ) {
	    $port++;
    }
  } until ( $available );

  return $port;
}


sub setPort
{
    my ($self, $port) = @_;

    # Save settings on the model
    my $uc = EBox::Global->modInstance('usercorner');
    my $settingsModel = $uc->model('Settings');
    $settingsModel->set(port => $port);
    $uc->save();
}

sub runGConf
{
  my ($self) = @_;

  my $port = $self->_availablePort();
  $self->addInternalService(
				    'name'            => 'usercorner',
				    'description'     => __('User Corner Web Server'),
				    'protocol'        => 'tcp',
				    'sourcePort'      => 'any',
				    'destinationPort' => $port,
				   );
  $self->setPort($port);
}

EBox::init();

my $uc = EBox::Global->modInstance('usercorner');
my $migration =  __PACKAGE__->new(
    'gconfmodule' => $uc,
    'version' => 1
);
$migration->execute();
