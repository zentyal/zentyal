#!/usr/bin/perl

#	Migration between gconf data version 4 to 5
#
#
#   This migration script changes the data type of some database columns
#   from CHAR to VARCHAR.
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
    my @sqls = (
        "DROP INDEX timestamp_i",
        "ALTER TABLE message RENAME TO mail_message",
        "ALTER TABLE mail_message RENAME COLUMN postfix_date TO timestamp",
        "CREATE INDEX timestamp_i ON mail_message(timestamp)"
    );
    for my $sql (@sqls) {
        my $cmd = qq{echo "$sql" | sudo su postgres -c'psql eboxlogs' > /dev/null 2>&1};
        system $cmd;
    }
}

EBox::init();

my $mod = EBox::Global->modInstance('mail');
my $migration = new EBox::Migration(
				    'gconfmodule' => $mod,
				    'version' => 5,
				   );

$migration->execute();
