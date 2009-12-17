#!/usr/bin/perl

#	Migration between gconf data version 5 to 6
#
#
#   This migration script renames the access table to squid_access if it exists
#
package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Global;
use EBox::MigrationHelpers;

sub runGConf
{
    EBox::MigrationHelpers::renameTable('access', 'squid_access');
}

EBox::init();

my $mod = EBox::Global->modInstance('squid');
my $migration = new EBox::Migration(
				    'gconfmodule' => $mod,
				    'version' => 6,
				   );

$migration->execute();
