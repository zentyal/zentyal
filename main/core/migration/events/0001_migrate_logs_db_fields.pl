#!/usr/bin/perl
# Copyright (C) 2010 eBox Technologies S.L.
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

#  Migration between gconf data version 0 and 1
#
#   db changes: source field is wider to accomadate longer source names


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
