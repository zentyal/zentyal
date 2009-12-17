#!/usr/bin/perl

#	Migration between gconf data version 5 to 6
#
#
#   This migration script changes the names of some fields and tables
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
    EBox::Migration::Helpers::dropIndex('timestamp_i');
    EBox::Migration::Helpers::renameField('message', 'postfix_date', 'timestamp');
    EBox::Migration::Helpers::renameTable('message', 'mail_message');
    EBox::Migration::Helpers::renameConsolidationTable('mail_traffic', 'mail_message_traffic');
    EBox::Migration::Helpers::createTimestampIndex('mail_message');
}

EBox::init();

my $mod = EBox::Global->modInstance('mail');
my $migration = new EBox::Migration(
				    'gconfmodule' => $mod,
				    'version' => 6,
				   );

$migration->execute();
