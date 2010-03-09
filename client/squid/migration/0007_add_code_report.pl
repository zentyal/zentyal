#!/usr/bin/perl

#	Migration between gconf data version 6 to 7
#
#
#   This migration script adds the code column to the report table
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Global;
use EBox::Migration::Helpers;

sub runGConf
{
    EBox::Migration::Helpers::addColumn('squid_access_report', 'code','VARCHAR(32)');
}

EBox::init();

my $mod = EBox::Global->modInstance('squid');
my $migration = new EBox::Migration(
				    'gconfmodule' => $mod,
				    'version' => 7,
				   );

$migration->execute();
