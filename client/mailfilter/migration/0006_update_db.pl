#!/usr/bin/perl
#
#       Migration between gconf data version 5 to 6
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
    # smtp mailfilter
    EBox::Migration::Helpers::dropIndex('timestamp_i');
    EBox::Migration::Helpers::renameField('message_filter', 'date', 'timestamp');
    EBox::Migration::Helpers::renameTable('message_filter', 'mailfilter_smtp');
    EBox::Migration::Helpers::renameConsolidationTable('mailfilter_traffic', 'mailfilter_smtp_traffic');
    EBox::Migration::Helpers::createTimestampIndex('mailfilter_smtp');

    # pop mailfilter
    EBox::Migration::Helpers::dropIndex('timestamp_pop_timestamp_i');
    EBox::Migration::Helpers::renameField('pop_proxy_filter', 'date', 'timestamp');
    EBox::Migration::Helpers::renameTable('pop_proxy_filter', 'mailfilter_pop');
    EBox::Migration::Helpers::renameConsolidationTable('pop_proxy_filter_traffic', 'mailfilter_pop_traffic');
    EBox::Migration::Helpers::createTimestampIndex('mailfilter_pop');
}

EBox::init();

my $mod = EBox::Global->modInstance('mailfilter');
my $migration = new EBox::Migration(
                                    'gconfmodule' => $mod,
                                    'version' => 6,
                                   );

$migration->execute();
