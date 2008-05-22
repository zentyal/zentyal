#!/usr/bin/perl
#
# This is a migration script to add a service and firewall rules
# for the eBox mail system
#
# For next releases we should be able to enable/disable some ports
# depening on if certain mail service is enabled or not
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
    my $serviceName = 'Mail system';
    if (not $service->serviceExists(name => $serviceName)) {
        $service->addMultipleService(
                'name' => $serviceName,
                'description' => __d('eBox Mail System'),
                'translationDomain' => 'ebox-mail',
                'internal' => 1,
                'services' => [ 
                                {
                                    'protocol' => 'tcp',
                                    'sourcePort' => 'any',
                                    'destinationPort' => 25,
                                },
                                {
                                    'protocol' => 'tcp',
                                    'sourcePort' => 'any',
                                    'destinationPort' => 110,
                                },
                                {
                                    'protocol' => 'tcp',
                                    'sourcePort' => 'any',
                                    'destinationPort' => 143,
                                },
                                {
                                    'protocol' => 'tcp',
                                    'sourcePort' => 'any',
                                    'destinationPort' => 995,
                                },
                                {
                                    'protocol' => 'tcp',
                                    'sourcePort' => 'any',
                                    'destinationPort' => 993,
                                }
                              ]);
   }

   $firewall->setExternalService($serviceName, 'deny');
   $firewall->setInternalService($serviceName, 'accept');
   $firewall->saveConfigRecursive(); 
}

EBox::init();

my $mailMod = EBox::Global->modInstance('mail');
my $migration =  __PACKAGE__->new( 
        'gconfmodule' => $mailMod,
        'version' => 1
        );
$migration->execute();
