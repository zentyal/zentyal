#!/usr/bin/perl

#  Migration between gconf data version 0 and 1
#
#   gconf changes: now service is explitted in intrnalService and userService
#   files changes: now log files names have the name of the daemon instead of
#   the iface daemons change: now start and stop of daemons have a new method
#   depending in pid files
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::MigrationBase';

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
