#!/usr/bin/perl
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
    my $serviceName = 'Mail system';
    my $id;
    if (not $service->serviceExists(name => $serviceName)) {
        $id = $service->addMultipleService(
                'name' => $serviceName,
                'description' => __d('eBox Mail System'),
                'translationDomain' => 'ebox-mail',
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
   } else {
       $id = $service->serviceId($serviceName); 
   }

   my $firewall = EBox::Global->getInstance()->modInstance('firewall');
   $firewall->setExternalService($id, 'deny');
}

EBox::init();

my $mailMod = EBox::Global->modInstance('mail');
my $migration =  __PACKAGE__->new( 
        'gconfmodule' => $mailMod,
        'version' => 1
        );
$migration->execute();
