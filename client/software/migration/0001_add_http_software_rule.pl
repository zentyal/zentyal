#!/usr/bin/perl
#   Migration between gconf data version 0 to 1
#
#   This migration script tries to add an HTTP service, and a rule to allow this
#   service to the Output rules

package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Error qw(:try);

sub _addFirewallRule
{
    my $global = EBox::Global->getInstance();
    my $servMod = $global->modInstance('services');
    my $servId;
    my $name = __d('HTTP software');
    if (not $servMod->serviceExists(name => $name)) {
        my $description = __d('software service to update packages via apt');
        $servId = $servMod->addService( name => $name,
                protocol => 'tcp',
                sourcePort => 'any',
                destinationPort => '80',
                internal => 0,
                readOnly => 0,
                description => $description,
                translationDomain => 'ebox-services');

    } else { 
        $servId = $servMod->serviceId($name);
    }

    my $fwMod = EBox::Global->modInstance('firewall');
    $fwMod->addOutputService( decision => 'accept', 
            destination =>  {destination_any => 'any'},
            service => { inverse => 0, value => $servId},
            description => __d('rule to allow apt updates'));

    $servMod->saveConfig();
    $global->modRestarted('services');

    if (not $fwMod->configured()) {
        $fwMod->saveConfig();
        $global->modRestarted('firewall');
    } else {
        $fwMod->save();
    }
}

sub runGConf
{
    my ($self) = @_;

    $self->_addFirewallRule;
}

EBox::init();

my $softwareMod = EBox::Global->modInstance('software');
my $migration =  __PACKAGE__->new( 
    'gconfmodule' => $softwareMod,
    'version' => 1
);
$migration->execute();
