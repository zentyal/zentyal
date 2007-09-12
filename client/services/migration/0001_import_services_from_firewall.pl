#!/usr/bin/perl

#	Migration between gconf data version 0 to 1
#
#	In version 1, a new model has been created to store services and it
#	lives in another module called services. In previous versions
#	servies were stored in firewall.
#	
#	This migration script tries to populate the services model with the
#	stored services in firewall
#
package EBox::Migration;
use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::NetWrappers qw(:all);
use EBox::Validate qw(:all);
use EBox::Gettext;

use base 'EBox::MigrationBase';

sub new 
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: runGConf
#
#
sub runGConf
{
    my $self = shift;
    
    my $servicesModule = EBox::Global->modInstance('services');
    
    $self->_addBaseServices($servicesModule);
    
    return unless (EBox::Global->instance()->modExists('firewall'));

    foreach my $service (@{$self->_firewallServices()}) {
        next if $servicesModule->serviceExists('name' => $service->{'name'});
        $servicesModule->addService('name' => $service->{'name'},
                'protocol' => $service->{'protocol'},
                'sourcePort' => 'any',
                'destinationPort' => $service->{'port'},
                'internal' => $service->{'internal'});
                                    
    }



}

sub _addBaseServices
{
    my ($self, $serviceMod) = @_;


    unless ($serviceMod->serviceExists('name' => 'any')) {
        $serviceMod->addService('name' => __d('any'),
                'description' => __d('any protocol and port'),
                'domain' => __d('ebox-services'),
                'protocol' => 'any', 
                'sourcePort' => 'any',
                'destinationPort' => 'any',
                'internal' => 0,
                'readOnly' => 1);
    }

    unless ($serviceMod->serviceExists('name' => 'any UDP')) {
        $serviceMod->addService('name' => __d('any UDP'),
                'description' => __d('any UDP port'),
                'domain' => __d('ebox-services'),
                'protocol' => 'udp', 
                'sourcePort' => 'any',
                'destinationPort' => 'any',
                'internal' => 0,
                'readOnly' => 1);
    }


    unless ($serviceMod->serviceExists('name' => 'any TCP')) {
        $serviceMod->addService('name' => __d('any TCP'),
                'description' => __d('any TCP port'),
                'domain' => __d('ebox-services'),
                'protocol' => 'tcp', 
                'sourcePort' => 'any',
                'destinationPort' => 'any',
                'internal' => 0,
                'readOnly' => 1);
    }
    
    unless ($serviceMod->serviceExists('name' => 'administration')) {
        $serviceMod->addService('name' => __d('eBox administration'),
                'description' => __d('eBox Administration port'),
                'domain' => __d('ebox-services'),
                'protocol' => 'tcp', 
                'sourcePort' => 'any',
                'destinationPort' => '443',
                'internal' => 1,
                'readOnly' => 1);
    }

    unless ($serviceMod->serviceExists('name' => 'ssh')) {
        $serviceMod->addService('name' => 'ssh',
                'description' => 'ssh',
                'domain' => __d('ebox-services'),
                'protocol' => 'tcp', 
                'sourcePort' => 'any',
                'destinationPort' => '22',
                'internal' => 0,
                'readOnly' => 1);
    }
}

sub _firewallServices
{
    my ($self) = @_;
    my $fwMod = EBox::Global->modInstance('firewall');

    my @array = ();
    my @objs = @{$fwMod->all_dirs_base("services")};
    foreach (@objs) {
        my $hash = $fwMod->hash_from_dir("services/$_");
        push(@array, $hash);
    }
    return \@array;
}

EBox::init();
my $services = EBox::Global->modInstance('services');
my $migration = new EBox::Migration( 
    'gconfmodule' => $services,
    'version' => 1
);
$migration->execute();
