#!/usr/bin/perl

#	Migration between gconf data version 3 to 4
#
#	
#   This migration script just tries to add a rule to allow outcoming
#   connections by eBox.
#
#   There's no migration from previous data as we only need to add a rule.
#
#   We only add the rule if the user has not added any output rule.
#
package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Data::Dumper;
use EBox::Model::ModelManager;
use Socket;
use Error qw(:try);




sub runGConf
{
    my ($self) = @_;
    my $fw = EBox::Model::ModelManager::instance()->model('EBoxOutputRuleTable');
    my $service = EBox::Model::ModelManager::instance()->model('ServiceTable');
    my $anyRow = $service->findValue(name => 'any');
    unless (defined($anyRow)) {
        EBox::warn('There must be something broken as I could not find "any" service');
        return;
    }
    $fw->add(
            decision => 'accept',
            destination => { 'destination_any' => undef},
            description => '',
            service => $anyRow->id()
            );

}

EBox::init();

my $fwMod = EBox::Global->modInstance('firewall');
my $migration = new EBox::Migration( 
				    'gconfmodule' => $fwMod,
				    'version' => 4,
				   );

$migration->execute();
