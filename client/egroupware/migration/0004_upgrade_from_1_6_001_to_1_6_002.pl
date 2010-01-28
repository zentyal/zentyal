#!/usr/bin/perl

#	Migration between gconf data version 3 to 4. This is needed whenever the
#   version changes so maybe it should be done somewhere else but for now ...
#
#	Migrate to latest DB version
#
package EBox::Migration;
use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;
use Error qw(:try);

use base 'EBox::Migration::Base';

sub runGConf
{
    my ($self) = @_;

    my $command = 'ebox-egroupware-update-db';
    EBox::Sudo::root(EBox::Config::share() . "/ebox-egroupware/$command");
}

EBox::init();

my $egw = EBox::Global->modInstance('egroupware');
my $migration = new EBox::Migration(
    'gconfmodule' => $egw,
    'version' => 4
);
$migration->execute();
