#!/usr/bin/perl
#
# This is a migration script to add a service and firewall rules
# for the eBox FTP service
#
# For next releases we should be able to enable/disable some ports
# depening on if certain mail service is enabled or not
#
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

    my $service = EBox::Global->getInstance()->modInstance('services');
    my $firewall = EBox::Global->getInstance()->modInstance('firewall');
    my $serviceName = 'FTP';
    if (not $service->serviceExists(name => $serviceName)) {
        $service->addMultipleService(
                'name' => $serviceName,
                'description' => __d('eBox FTP Server'),
                'translationDomain' => 'ebox-ftp',
                'internal' => 1,
                'services' => [
                                {
                                    'protocol' => 'tcp',
                                    'sourcePort' => 'any',
                                    'destinationPort' => 20,
                                },
                                {
                                    'protocol' => 'tcp',
                                    'sourcePort' => 'any',
                                    'destinationPort' => 21,
                                },
                              ]);
   }

   $firewall->setExternalService($serviceName, 'accept');
   $firewall->setInternalService($serviceName, 'accept');
   $firewall->saveConfigRecursive();
}

EBox::init();

my $ftpMod = EBox::Global->modInstance('ftp');
my $migration = __PACKAGE__->new(
        'gconfmodule' => $ftpMod,
        'version' => 1
        );
$migration->execute();
