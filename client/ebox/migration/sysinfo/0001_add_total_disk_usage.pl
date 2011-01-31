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

#   Migration between data version 0 and 1
#
#
#   This migration script add total values for disk_usage report
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::DBEngineFactory;
use EBox::Global;
use EBox::Sudo;

sub runGConf
{
    my ($self) = @_;

    my $dbh = EBox::DBEngineFactory::DBEngine();

    my $sqlQuery = 'INSERT INTO sysinfo_disk_usage_report(date, mountpoint, used, free) '
                   . "SELECT date, 'total', sum(used), sum(free) "
                   . 'FROM sysinfo_disk_usage_report '
                   . "WHERE mountpoint <> 'total' "
                   . 'GROUP BY date';

    $dbh->do($sqlQuery);

}

EBox::init();

my $mod = EBox::Global->modInstance('sysinfo');
my $migration = new EBox::Migration(
				    'gconfmodule' => $mod,
				    'version' => 1,
				   );

$migration->execute();

