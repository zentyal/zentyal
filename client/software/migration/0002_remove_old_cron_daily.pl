#!/usr/bin/perl
#   Migration between gconf data version 1 to 2
#
#   This migration script removes the old /etc/cron.daily/ebox-software file if
#   exists

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Error qw(:try);


sub runGConf
{
    my ($self) = @_;

    EBox::Sudo::root("rm -f /etc/cron.daily/ebox-software");
}

EBox::init();

my $softwareMod = EBox::Global->modInstance('software');
my $migration =  __PACKAGE__->new(
    'gconfmodule' => $softwareMod,
    'version' => 2
);
$migration->execute();
