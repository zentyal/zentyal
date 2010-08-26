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

#  Migration between gconf data version 0 and 1
#
#   gconf changes: now service is explitted in intrnalService and userService
#   files changes: now log files names have the name of the daemon instead of
#   the iface daemons change: now start and stop of daemons have a new method
#   depending in pid files
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use Error qw(:try);

use EBox;
use EBox::Global;
use EBox::Sudo;
use EBox::Config;

use EBox::DBEngineFactory;



sub runGConf
{
  my ($self) = @_;
  $self->_migrateTables();
}


sub _migrateTables
{
    my ($self) = @_;
    my $dbEngine = EBox::DBEngineFactory::DBEngine();

    my $dbName = EBox::Config::configkey("eboxlogs_dbname");
    my @tables = (
        'squid_traffic_daily',
        'squid_traffic_hourly',
        'squid_traffic_monthly',
        'squid_traffic_weekly',
       );

    my $newColumn = 'rfc931';

    foreach my $table (@tables) {
#         my $columnFound = 0;

#         try {
#             $dbEngine->do("SELECT $newColumn FROM $table LIMIT 1");
#             $columnFound = 1;
#         }
#         otherwise {
#             $columnFound = 0;
#         };


#         $columnFound and
#             next;

        my @sqlCmds = (
                       qq{ALTER TABLE $table ADD $newColumn CHAR(255)},
                       qq{ALTER TABLE $table ALTER $newColumn SET DEFAULT '-'},
                       qq(UPDATE $table SET $newColumn='-' WHERE $newColumn = NULL)
                      );

        foreach my $sql (@sqlCmds) {
            my $cmd = qq{echo "$sql" | sudo su postgres -c'psql eboxlogs' > /dev/null 2>&1};
            system $cmd;
        }


    }
}


EBox::init();
my $squid = EBox::Global->modInstance('squid');
my $migration = new EBox::Migration(
                                     'gconfmodule' => $squid,
                                     'version' => 4,
                                    );
$migration->execute();


1;
