#!/usr/bin/perl

#
# This is a migration script to add a service and firewall rules
# for the eBox Zarafa server 
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

    my $serviceName = 'zarafa';
    if (not $service->serviceExists(name => $serviceName)) {
        $service->addMultipleService(
                'name' => $serviceName,
                'description' => __d('Zarafa Server'),
                'translationDomain' => 'ebox-zarafa',
                'internal' => 1,
                'readOnly' => 1,
                'services' => [
                                { # zarafa-server
                                    'protocol' => 'tcp',
                                    'sourcePort' => 'any',
                                    'destinationPort' => '236',
                                },
                                { # zarafa-server
                                    'protocol' => 'tcp',
                                    'sourcePort' => 'any',
                                    'destinationPort' => '237',
                                },
                                { # zarafa-gateway
                                    'protocol' => 'tcp',
                                    'sourcePort' => 'any',
                                    'destinationPort' => '110',
                                },
                                { # zarafa-gateway
                                    'protocol' => 'tcp',
                                    'sourcePort' => 'any',
                                    'destinationPort' => '995',
                                },
                                { # zarafa-gateway
                                    'protocol' => 'tcp',
                                    'sourcePort' => 'any',
                                    'destinationPort' => '143',
                                },
                                { # zarafa-gateway
                                    'protocol' => 'tcp',
                                    'sourcePort' => 'any',
                                    'destinationPort' => '993',
                                },
                                { # zarafa-icalserver
                                    'protocol' => 'tcp',
                                    'sourcePort' => 'any',
                                    'destinationPort' => '8080',
                                },
                              ]);
   }

   $firewall->setExternalService($serviceName, 'deny');
   $firewall->setInternalService($serviceName, 'accept');
   $firewall->saveConfigRecursive();
}

EBox::init();

my $mod = EBox::Global->modInstance('zarafa');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mod,
        'version' => 1
        );
$migration->execute();
