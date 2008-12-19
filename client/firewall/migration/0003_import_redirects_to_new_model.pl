#!/usr/bin/perl

#	Migration between gconf data version 2 to 3
#
#	In version 3, a new model has been created to store firewall redirects.
#	
#	This migration script tries to populate the redirects model with the
#	stored redirects in old firewall
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


sub _oldFirewallRedirects
{
    my $fwMod = EBox::Global->modInstance('firewall');

    my @array = ();
    my @redirects = @{$fwMod->all_dirs_base("redirections")};
    foreach my $redirect (@redirects) {
        my $hash = $fwMod->hash_from_dir("redirections/$redirect");
        push(@array, $hash);
    }
    return \@array;
}

sub _prepareNewRedirect
{
    my ($redirect, $object) = @_;
    
    use Data::Dumper;
    EBox::info("Adding service new redirection for old redirection: " . Dumper($redirect));

    my %params;

    $params{'interface'} = $redirect->{'iface'};
    $params{'destination'} = $redirect->{'ip'};
    $params{'external_port_range_type'} = 'single';
    $params{'protocol'} = $redirect->{'protocol'};
    $params{'external_port_single_port'} = $redirect->{'eport'};
    if ($redirect->{'eport'} == $redirect->{'dport'}) {
        $params{'destination_port_selected'} = 'destination_port_same';
    } else {
        $params{'destination_port_selected'} = 'destination_port_other';
        $params{'destination_port_other'} = $redirect->{'dport'};
    }
    $params{'source_selected'} = 'source_any';

#print Dumper(\%params);
    return \%params;
}

sub _addRedirectsRuleTable
{
    my ($self) = @_;
    my $model = EBox::Model::ModelManager->instance()
                                         ->model('RedirectsTable');
    my @redirects;
    for my $oldRedirect (@{_oldFirewallRedirects()}) {
        push (@redirects, _prepareNewRedirect($oldRedirect));
    }

    for my $redirect (@redirects) {
        try {
            $model->addRow(%{$redirect});
        } otherwise {
            EBox::warn("Error adding " . Dumper ($redirect) . "\n");
        };
    }
}

sub runGConf
{
    my ($self) = @_;

    $self->_addRedirectsRuleTable();
     
    my $fwMod = EBox::Global->modInstance('firewall');
    $fwMod->saveConfig();
}

EBox::init();

my $fw = EBox::Global->modInstance('firewall');
my $migration = new EBox::Migration( 
    'gconfmodule' => $fw,
    'version' => 3
);
$migration->execute();
