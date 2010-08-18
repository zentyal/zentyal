#!/usr/bin/perl


package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Migration::Helpers;
use EBox::Gettext;

sub runGConf
{
    my ($self) = @_;

    my $query = "ALTER TABLE jobs " .
        "ALTER COLUMN printer TYPE VARCHAR(255) USING rtrim(printer), " .
        "ALTER COLUMN owner TYPE VARCHAR(255) USING rtrim(owner), " .
        "ALTER COLUMN event TYPE VARCHAR(255) USING rtrim(event)" ;


    my $cmd = qq{echo "$query" | sudo su postgres -c'psql eboxlogs' > /dev/null 2>&1};
    system $cmd;


    EBox::Migration::Helpers::renameTable('jobs', 'printers_jobs');


}


EBox::init();

my $printersMod = EBox::Global->modInstance('printers');
my $migration =  __PACKAGE__->new(
    'gconfmodule' => $printersMod,
    'version' => 3
);
$migration->execute();
