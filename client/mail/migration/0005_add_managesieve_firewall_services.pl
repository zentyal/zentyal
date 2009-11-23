#!/usr/bin/perl
#
# This is a migration script to add a service and firewall rules
# for the manageSIEVE service
#
#
package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Error qw(:try);

sub runGConf
{
    my ($self) = @_;

    my $service = EBox::Global->getInstance()->modInstance('services');
    my $firewall = EBox::Global->getInstance()->modInstance('firewall');
    my $serviceName = 'manageSIEVE';
    if (not $service->serviceExists(name => $serviceName)) {
        $service->addService(
                'name' => $serviceName,
                'description' => __d('protocol for editing SIEVE filters'),
                'translationDomain' => 'ebox-mail',
                'internal' => 1,
                'protocol'   => 'tcp',
                'sourcePort' => 'any',
                 'destinationPort' => 4190,
                              );
   }

   $firewall->setExternalService($serviceName, 'deny');
   $firewall->setInternalService($serviceName, 'accept');
   $firewall->saveConfigRecursive();
}

EBox::init();

my $mailMod = EBox::Global->modInstance('mail');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mailMod,
        'version' => 5,
        );
$migration->execute();
