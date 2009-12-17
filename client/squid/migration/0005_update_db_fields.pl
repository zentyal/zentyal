#!/usr/bin/perl

#	Migration between gconf data version 4 to 5
#
#
#   This migration script changes the data type of some database columns
#   from CHAR to VARCHAR.
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Global;

sub runGConf
{
    my ($self) = @_;
    my $query = "ALTER TABLE access " .
        "ALTER COLUMN remotehost TYPE VARCHAR(255) USING rtrim(remotehost), " .
        "ALTER COLUMN code TYPE VARCHAR(255) USING rtrim(code), " .
        "ALTER COLUMN method TYPE VARCHAR(10) USING rtrim(method), " .
        "ALTER COLUMN url TYPE VARCHAR(1024) USING rtrim(url), " .
        "ALTER COLUMN rfc931 TYPE VARCHAR(255) USING rtrim(rfc931), " .
        "ALTER COLUMN peer TYPE VARCHAR(255) USING rtrim(peer), " .
        "ALTER COLUMN mimetype TYPE VARCHAR(255) USING rtrim(mimetype), " .
        "ALTER COLUMN filterProfile TYPE VARCHAR(100) USING rtrim(filterProfile)";

    my $cmd = qq{echo "$query" | sudo su postgres -c'psql eboxlogs' > /dev/null 2>&1};
    system $cmd;
}

EBox::init();

my $mod = EBox::Global->modInstance('squid');
my $migration = new EBox::Migration(
				    'gconfmodule' => $mod,
				    'version' => 5,
				   );

$migration->execute();
