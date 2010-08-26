#!/usr/bin/perl

# Copyright (C) 2008-2010 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

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

use base 'EBox::Migration::Base';


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
