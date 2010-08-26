#!/usr/bin/perl

# Copyright (C) 2008-2010 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

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
