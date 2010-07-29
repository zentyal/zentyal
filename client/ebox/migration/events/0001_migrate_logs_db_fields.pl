#!/usr/bin/perl


package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;

sub runGConf
{
    my ($self) = @_;

    # change source field to 256 chars
    my @tables = qw(events events_report events_accummulated_hourly
                    events_accummulated_daily  events_accummulated_weekly 
                    events_accummulated_monthly );
    foreach my $table (@tables) {
        my $query = "ALTER TABLE $table " .
        "ALTER COLUMN source TYPE VARCHAR(256)";


        my $cmd = qq{echo "$query" | sudo su postgres -c'psql eboxlogs' > /dev/null 2>&1};
        system $cmd;
    }

}


EBox::init();

my $printersMod = EBox::Global->modInstance('events');
my $migration =  __PACKAGE__->new(
    'gconfmodule' => $printersMod,
    'version' => 1
);
$migration->execute();
