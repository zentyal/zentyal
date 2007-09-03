#!/usr/bin/perl

#	Migration between gconf data version 0 to 1
#
#	In version 1, a new model has been created to store firewall rules and it
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
use EBox::Gettext;
use Data::Dumper;
use EBox::Model::ModelManager;
use Socket;
use Error qw(:try);

use base 'EBox::MigrationBase';


sub _firewallRulesForObjectsToInternet
{
    my $fwMod = EBox::Global->modInstance('firewall');

    my @array = ();
    my @objs = @{$fwMod->all_dirs_base("objects")};
    foreach my $object (@objs) {
        my $hash = $fwMod->hash_from_dir("objects/$object");
        $hash->{'name'} = $object;
        my @rules;
        foreach my $ruleId (@{$fwMod->all_dirs_base("objects/$object/rules")}) {
            push (@rules,
                $fwMod->hash_from_dir("objects/$object/rules/$ruleId"));
        }
        $hash->{'rules'} = \@rules;
        push(@array, $hash);
    }
    return \@array;
}

sub _firewallRulesForObjectsToEBox
{
    my $fwMod = EBox::Global->modInstance('firewall');

    my @array = ();
    my @objs = @{$fwMod->all_dirs_base("objects")};
    foreach my $object (@objs) {
        my $hash = $fwMod->hash_from_dir("objects/$object");
        $hash->{'name'} = $object;
        my @services;
        my $servicesKey = "objects/$object/services";
        foreach my $service (@{$fwMod->all_dirs_base($servicesKey)}) {
            push (@services,
                $fwMod->hash_from_dir("$servicesKey/$service"));
        }
        $hash->{'services'} = \@services;
        push(@array, $hash);
    }
    return \@array;
}

sub _addService
{
    my ($rule) = @_;

    my $serviceMod = EBox::Global->modInstance('services');

    my $anyId;
    if (not defined($rule->{'port'}) and defined($rule->{'protocol'})) {
        my $anyId;
        if ($rule->{'protocol'} eq 'udp') {
            $anyId = $serviceMod->serviceId('any UDP');
        } else {
            $anyId = $serviceMod->serviceId('any TCP');
        }
        unless (defined($anyId)) {
            die "there is no any $rule->{protocol} service";
        }
        return $anyId;
    } elsif (not defined($rule->{'port'}) and not defined($rule->{'protocol'})) {
       $anyId = $serviceMod->serviceId('any');
        unless (defined($anyId)) {
            die 'there is no "any" service';
        }
        return $anyId;
    }

    my $serviceName = getservbyport ($rule->{'port'}, $rule->{'protocol'});
    my $description  =  $rule->{'port'} . '/' . $rule->{'protocol'};
    unless (defined($serviceName)) {
        $serviceName = $description; 
    }
    my $serviceId = $serviceMod->serviceId($serviceName);
    unless (defined($serviceId))  {
        $serviceId = $serviceMod->addService('name' => $serviceName,
            'description' => $description,				
            'protocol' => $rule->{'protocol'},
            'sourcePort' => 'any',
            'destinationPort' => $rule->{'port'},
            'internal' => 0);
    }

    return $serviceId;
}

sub _prepareRuleToAddInternalToInternet
{
    my ($rule, $object) = @_;
    
    my $serviceId = _addService($rule);
    my %params;
    if ($rule->{'action'} eq 'allow') {
        $params{'decision'} = 'accept';
    } else {
        $params{'decision'} = 'deny';
    }

    if ($object->{'name'} eq '_global') {
        $params{'source_selected'} = 'source_any';
    } else {
        $params{'source_selected'} = 'source_object';
        $params{'source_object'} = $object->{'name'};
    }

    if ($rule->{'address'}) {
        $params{'destination_ipaddr_ip'} =  $rule->{'address'};
        $params{'destination_selected'} = 'destination_ipaddr';
    } else { 
        $params{'destination_selected'} = 'destination_any';
    }

    $params{'destination_ipaddr_mask'} = $rule->{'mask'};
    $params{'service'} = $serviceId;
    $params{'log'} = 0;

#print Dumper(\%params);
    return \%params;
}

sub _prepareRuleToAddInternalToEBox
{
    my ($rule, $object) = @_;
    my $serviceMod = EBox::Global->modInstance('services');
    my $serviceId = $serviceMod->serviceId($rule->{'name'});

    my %params;
    if ($rule->{'policy'} eq 'allow') {
        $params{'decision'} = 'accept';
    } else {
        $params{'decision'} = 'deny';
    }
    
    if ($object->{'name'} eq '_global') {
        $params{'source_selected'} = 'source_any';
    } else {
        $params{'source_selected'} = 'source_object';
        $params{'source_object'} = $object->{'name'};
    }
    
    $params{'service'} = $serviceId;
    $params{'log'} = 0;

    print Dumper(\%params);
    return \%params;
}

sub _prepareObjectPolicy
{
    my ($object) = @_;
    my $rule = {};
    my $serviceId = _addService($rule);
    my %params;
    if ($object->{'policy'} eq 'allow') {
        $params{'decision'} = 'accept';
    } else {
        $params{'decision'} = 'deny';
    }
    $params{'source_selected'} = 'source_object';
    $params{'source_object'} = $object->{'name'};
    $params{'destination_selected'} = 'destination_any';
    $params{'service'} = $serviceId;
    $params{'log'} = 0;

    return \%params;
}

sub _addToInternetRuleTable
{
    my ($self) = @_;
    my $model = EBox::Model::ModelManager->instance()
                                         ->model('ToInternetRuleTable');
    my @rules;
    my $global;
    for my $object (@{_firewallRulesForObjectsToInternet()}) {
        if ($object->{'name'} eq '_global') {
            $global = $object;
            next;
        }
        push (@rules, _prepareObjectPolicy($object));
        for my $rule(@{$object->{'rules'}}) {
               push (@rules,_prepareRuleToAddInternalToInternet($rule, $object) );
        }

    }

    if ($global) {
        for my $rule (@{$global->{'rules'}}) {
            push (@rules,
                    _prepareRuleToAddInternalToInternet($rule, $global));
        }
    }

    for my $rule(@rules) {
        try {
            $model->addRow(%{$rule});
        } otherwise {
            EBox::warn("Error adding " . Dumper ($rule) . "\n");
        };
    }
}

sub _addInternalToEBoxRuleTable
{
    my ($self) = @_;
    my $model = EBox::Model::ModelManager->instance()
                                         ->model('InternalToEBoxRuleTable');
    my @rules;
    my $global;
    for my $object (@{_firewallRulesForObjectsToEBox()}) {
        if ($object->{'name'} eq '_global') {
            $global = $object;
            next;
        }
        for my $rule (@{$object->{'services'}}) {
               push (@rules,_prepareRuleToAddInternalToEBox($rule, $object) );
       }
    }

    if ($global) {
        for my $rule (@{$global->{'services'}}) {
	    @rules = (_prepareRuleToAddInternalToEBox($rule, $global), @rules);
                  
        }
    }
    
    for my $rule(@rules) {
        try {
            $model->addRow(%{$rule});
        } otherwise {
            EBox::warn("Error adding " . Dumper ($rule) . "\n");
        };
    }

}

sub runGConf
{
    my ($self) = @_;

    _addToInternetRuleTable
    _addToInternetRuleTable();
     
    my $serviceMod = EBox::Global->modInstance('services');
    $serviceMod->save();
}

EBox::init();
_addInternalToEBoxRuleTable();
my $fw = EBox::Global->modInstance('firewall');
my $migration = new EBox::Migration( 
    'gconfmodule' => $fw,
    'version' => 1
);
$migration->execute();
