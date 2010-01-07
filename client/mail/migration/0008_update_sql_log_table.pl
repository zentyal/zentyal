#!/usr/bin/perl
#
# This is a migration script to add the LDAP data for fetchmail feature
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
    my $sqlCommand = 'ALTER TABLE message ALTER COLUMN status DROP NOT NULL';
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
