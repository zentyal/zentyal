#!/usr/bin/perl

# Copyright (C) 2011 eBox Technologies S.L.
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


package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use Error qw(:try);

sub runGConf
{
    my ($self) = @_;

    try {
        my $monMod = $self->{gconfmodule};
        my $measureWatcherModel = $monMod->model('MeasureWatchers');

        foreach my $id ( @{$measureWatcherModel->ids()} ) {
            my $measureWatcher = $measureWatcherModel->row($id);
            my $confModel      = $measureWatcher->subModel('thresholds');
            foreach my $confId ( @{$confModel->ids()} ) {
                my $key = $confModel->{directory} . "/$confId";
                my $persist = $monMod->get_bool("$key/persist");
                my $value   = { persist_always => 1 };
                unless ( $persist ) {
                    $value = { persist_once => 1 };
                }
                $confModel->set( $confId, persist => $value );
                EBox::info('Set new persist value in "'
                           . $measureWatcher->printableValueByName('measure')
                           . '" thresholds');
            }
        }
    } otherwise { };

}

EBox::init();

my $monMod = EBox::Global->modInstance('monitor');
my $migration =  __PACKAGE__->new(
    'gconfmodule' => $monMod,
    'version' => 1
);
$migration->execute();
