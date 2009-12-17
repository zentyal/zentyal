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

use base 'EBox::Migration::Base';

sub runGConf
{
    my ($self) = @_;

    my $egw = $self->{gconfmodule};

    my $command = 'ebox-egroupware-regen-db';
    try {
        $egw->save();
# Disable this for avoid risk of losing data after broken migration
#        EBox::Sudo::root(EBox::Config::share() . "/ebox-egroupware/$command");
    } catch Error with {};
}

EBox::init();

my $egw = EBox::Global->modInstance('egroupware');
my $migration = new EBox::Migration(
    'gconfmodule' => $egw,
    'version' => 2
);
$migration->execute();
