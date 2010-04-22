#!/usr/bin/perl

#   Fix addColumn from 0006_update_db.pl

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
    EBox::Migration::Helpers::addColumn('mail_message', 'message_type', 'VARCHAR(10)');
}

EBox::init();

my $mod = EBox::Global->modInstance('mail');
my $migration = new EBox::Migration(
				    'gconfmodule' => $mod,
				    'version' => 12,
				   );

$migration->execute();
