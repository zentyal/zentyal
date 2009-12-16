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

sub runGConf
{
    my ($self) = @_;

    my $exists_query = "SELECT COUNT(*) FROM access";
    my @queries = (
        "ALTER TABLE squid_access RENAME TO squid_access_new",
        "ALTER TABLE access RENAME TO squid_access",
        "INSERT INTO squid_access SELECT * FROM squid_access_new",
        "DROP TABLE squid_access_new"
    );

    my $cmd = qq{echo "$exists_query" | sudo su postgres -c 'psql eboxlogs' > /dev/null 2>&1};
    system $cmd;
    if ($? == 0) {
        for my $q (@queries) {
            $cmd = qq{echo "$q" | sudo su postgres -c 'psql eboxlogs' > /dev/null 2>&1};
            system $cmd;
        }
    }
}

EBox::init();

my $mod = EBox::Global->modInstance('squid');
my $migration = new EBox::Migration(
				    'gconfmodule' => $mod,
				    'version' => 6,
				   );

$migration->execute();
