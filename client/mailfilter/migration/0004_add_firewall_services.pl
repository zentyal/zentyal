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

    my $service = EBox::Global->modInstance('services');
    my $firewall = EBox::Global->modInstance('firewall');
    my $mailfilter = EBox::Global->modInstance('mailfilter');

    my $proxyServiceName = 'POP Transparent proxy';
    if (not $service->serviceExists(name => $proxyServiceName)) {
        $service->addService(
                             'name' => $proxyServiceName,
                             'description' => __d('POP transparent proxy'),
                             'translationDomain' => 'ebox-mailfilter',
                             'internal' => 1,
                             'protocol' => 'tcp',
                             'sourcePort' => 'any',
                             'destinationPort' => $mailfilter->popProxy()->port(),

                            );
   }

   $firewall->setExternalService($proxyServiceName, 'deny');
   $firewall->setInternalService($proxyServiceName, 'accept');


    my $popServiceName = 'POP3';
    if (not $service->serviceExists(name => $popServiceName)) {
        $service->addService(
                             'name' => $popServiceName,
                             'description' => __d('POP3 protocol'),
                             'translationDomain' => 'ebox-mailfilter',
                             'internal' => 1,
                             'protocol' => 'tcp',
                             'sourcePort' => 'any',
                             'destinationPort' => 110,

                            );
   }


    setFirewallService($firewall, 'ToInternetRuleModel', $popServiceName, 'accept', 1);
    setFirewallService($firewall, 'EBoxOutputRuleModel', $popServiceName, 'accept', 0);

    
    $firewall->saveConfigRecursive(); 
}



sub setFirewallService
{
    my ($firewall, $model, $service, $decision, $source) = @_;

    my $serviceMod = EBox::Global->modInstance('services');

    unless (defined($service)) {
        throw EBox::Exceptions::MissingArgument('service');
    }
    
    unless (defined($decision)) {
        throw EBox::Exceptions::MissingArgument('decision');
    }

    unless ($decision eq 'accept' or $decision eq 'deny') {
        throw EBox::Exceptions::InvalidData('data' => 'decision', 
                        value => $decision, 'advice' => 'accept or deny');
    }

    my $serviceId = $serviceMod->serviceId($service);

    unless (defined($serviceId)) {
        throw EBox::Exceptions::DataNotFound('data' => 'service',
                                             'value' => $service);
    }

    my $rulesModel = $firewall->{$model};
    
    # Do not add rule if there is already a rule
    if ($rulesModel->findValue('service' => $serviceId)) {
        EBox::info("Existing rule for $service overrides default rule");
        return undef;
    }

    my %params;
    $params{'decision'} = $decision;
    if ($source) {
        $params{'source_selected'} = 'source_any';
    }

    $params{'destination_selected'} = 'destination_any';
    $params{'service'} = $serviceId;
    
    $rulesModel->addRow(%params);
    
    return 1;
}

EBox::init();

my $mailfilterMod = EBox::Global->modInstance('mailfilter');
my $migration =  __PACKAGE__->new( 
        'gconfmodule' => $mailfilterMod,
        'version' => 4,
        );
$migration->execute();
1;


