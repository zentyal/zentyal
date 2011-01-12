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
