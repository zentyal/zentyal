#!/usr/bin/perl

#
# This is a migration script to add a service and firewall rules
# for the Zentyal Jabber server
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

    my $serviceName = 'jabber';
    if (not $service->serviceExists(name => $serviceName)) {
        $service->addMultipleService(
                'name' => $serviceName,
                'description' => __d('Jabber Server'),
                'translationDomain' => 'ebox-jabber',
                'internal' => 1,
                'readOnly' => 1,
                'services' => [
                                { # jabber c2s
                                    'protocol' => 'tcp',
                                    'sourcePort' => 'any',
                                    'destinationPort' => '5222',
                                },
                                { # jabber c2s
                                    'protocol' => 'tcp',
                                    'sourcePort' => 'any',
                                    'destinationPort' => '5223',
                                },
                              ]);
   }

   $firewall->setExternalService($serviceName, 'deny');
   $firewall->setInternalService($serviceName, 'accept');
   $firewall->saveConfigRecursive();
}

EBox::init();

my $mod = EBox::Global->modInstance('jabber');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mod,
        'version' => 1
        );
$migration->execute();
