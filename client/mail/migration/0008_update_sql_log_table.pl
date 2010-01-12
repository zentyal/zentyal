#!/usr/bin/perl
#
# This is a migration script to remove the NOT NULL condition for te column
# status in log table. NOT NULL conditon must be removed to avoid ilog insert fails 
#
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Config;
use EBox::Sudo;
use File::Slurp;



sub runGConf
{
    my ($self) = @_;

    my $cmdFile    = '/tmp/0007updateSqlTableXAZ';
    my $sqlCommand = 'ALTER TABLE mail_message ALTER COLUMN status DROP NOT NULL';
    File::Slurp::write_file($cmdFile, $sqlCommand);
    my $shellCommand = qq{su postgres -c'psql -f $cmdFile eboxlogs'};
    EBox::Sudo::root($shellCommand);
    EBox::Sudo::root("rm -rf $cmdFile");
}



EBox::init();

my $mailMod = EBox::Global->modInstance('mail');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mailMod,
        'version' => 8,
        );
$migration->execute();
