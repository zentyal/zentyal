#!/usr/bin/perl

#	Migration between gconf data version 2 and 3
#
#
#   This migration script creates the plpgsql language
#
package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Global;

sub runGConf
{
    my ($self) = @_;

    my $cmd = qq{echo "CREATE LANGUAGE plpgsql" | sudo su postgres -c 'psql eboxlogs' > /dev/null 2>&1};
    system $cmd;
}

EBox::init();

my $mod = EBox::Global->modInstance('logs');
my $migration = new EBox::Migration(
				    'gconfmodule' => $mod,
				    'version' => 3,
				   );

$migration->execute();
