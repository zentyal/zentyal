#!/usr/bin/perl

#	Migration between gconf data version 1 to 2
#
#	With the introduction of eGroupware 1.6 we need to migrate the old
#   data from existing eGroupware 1.4 installations.
#
package EBox::Migration;
use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;
use Error qw(:try);

use base 'EBox::MigrationBase';

sub runGConf
{
    my ($self) = @_;

    my $egw = $self->{gconfmodule};
    $egw->save();

    my $command = "ebox-egroupware-regen-db";
    EBox::Sudo::root(EBox::Config::share() . "/ebox-egroupware/$command");
}

EBox::init();

my $egw = EBox::Global->modInstance('egroupware');
my $migration = new EBox::Migration(
    'gconfmodule' => $egw,
    'version' => 2
);
$migration->execute();
