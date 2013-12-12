# Copyright (C) 2010-2011 Zentyal S.L.
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

use strict;
use warnings;


#
use Test::MockTime qw(:all);
use EBox;
use EBox::DBEngineFactory;
use EBox::Module::Base;

use Test::MockObject::Extends;
use Test::Exception;
use Test::More qw(no_plan);
use Test::Differences;

diag 'This tests writes in the postgre database. DONT USE IN PRODUCTION';
EBox::init();


my $firstRoundTime =  '2010-07-23 17:45:05';
my $secondRoundTime = '2010-08-28 10:45:05';


_setFixedTime($firstRoundTime);


my $db = EBox::DBEngineFactory::DBEngine();
_clearDB($db);
_setupDB($db);
my $module = _mockModule();

_consolidationInfoReportFirstRound($module, $db);

diag 'Executed consolidation a second time, we will sue the same checks to assure nothing has changed after the consolidation';
 _consolidationInfoReportFirstRound($module, $db);


 _setFixedTime($secondRoundTime);

 _prepareSecondRound($db);
 _consolidationInfoReportSecondRound($module, $db);
diag 'Executed consolidation one more time, we will use the same checks to assure nothing has changed after the consolidation';
 _consolidationInfoReportSecondRound($module, $db);

    # clear any data from previous run
sub _clearDB
{
    my ($db) = @_;

    my @dbTables = ('test_disk_usage', 'test_disk_usage_report');
    foreach my $table (@dbTables) {
        my $dropSql = "DROP TABLE IF EXISTS $table;";
        $db->do($dropSql);
        my $deleteFromConsolidationSql = "delete from report_consolidation WHERE  report_table='$table';";
        $db->do($deleteFromConsolidationSql);
    }

}


sub _setupDB
{
    my ($db) = @_;

    my $createTableSql = q{CREATE TABLE test_disk_usage (timestamp TIMESTAMP, mountpoint VARCHAR(40), free INT, used INT   ); };
    $db->do($createTableSql);

     $createTableSql = q{CREATE TABLE  test_disk_usage_report (date DATE, mountpoint VARCHAR(40), free INT, used INT  ); };
    $db->do($createTableSql);


    my @data = (
                {
                 timestamp => '2009-09-23 10:34:05',
                 mountpoint => '/media/hda1',
                 free => 300,
                 used => 3923,
                },
                {
                 timestamp => '2009-12-31 22:34:05',
                 mountpoint => '/media/hda2',
                 free => 512,
                 used => 3123,
                },
                {
                 timestamp => '2010-02-18 22:34:05',
                 mountpoint => '/media/hda2',
                 free => 161,
                 used => 1273,
                },
                {
                 timestamp => '2010-02-24 12:34:05',
                 mountpoint => '/media/hda2',
                 free => 412,
                 used => 3973,
                },
                {
                 timestamp => '2010-02-24 22:14:14',
                 mountpoint => '/media/hdc1',
                 free => 124,
                 used => 3913,
                },
                {
                 timestamp => '2010-07-05 06:06:06',
                 mountpoint => '/media/hda2',
                 free => 124,
                 used => 2173,
                },
                {
                 timestamp => '2010-07-05 06:06:07',
                 mountpoint => '/media/hda2',
                 free => 412,
                 used => 2500,
                },
                {
                 timestamp => '2010-07-05 06:06:06',
                 mountpoint => '/media/hda1',
                 free => 2347,
                 used => 2373,
                },
                {
                 timestamp => '2010-07-12 09:06:06',
                 mountpoint => '/media/hda1',
                 free => 33,
                 used => 3233,
                },
                # upper time limit value
                {
                 timestamp => '2010-07-23 17:45:05',
                 mountpoint => '/media/hdc2',
                 free => 342,
                 used => 3273,
                },
               );


    foreach my $values (@data) {
        $db->insert('test_disk_usage', $values);
    }
    $db->multiInsert();

}


sub _mockModule
{
    my $mod = EBox::Module::Base->_create(
                       name => 'test',
                       domain => 'test',
                       printableName => 'test',
                       title          => 'test'
                                );

    $mod = Test::MockObject::Extends->new( $mod );
    $mod->mock('consolidateReportInfoQueries' => \&moduleConsolidateReportInfoQueries);


    return $mod;
}



sub moduleConsolidateReportInfoQueries
{
    return [
        {
            'target_table' => 'test_disk_usage_report',
            'query' => {
                'select' => 'mountpoint, used, free',
                'from' => 'test_disk_usage',
                'key' => 'mountpoint',
#                'updateMode' => 'overwrite',
            }
        }
    ];



}

sub firstRoundExpectedTables
{
    my @expectedDiskUsage = (
                {
                 date => '2009-09-01',
                 mountpoint => '/media/hda1',
                 free => 300,
                 used => 3923,
                },
                {
                 date => '2009-12-01',
                 mountpoint => '/media/hda2',
                 free => 512,
                 used => 3123,
                },
                {
                 date => '2010-02-01',
                 mountpoint => '/media/hda2',
                 free => 412,
                 used => 3973,
                },
                {
                 date => '2010-02-01',
                  mountpoint => '/media/hdc1',
                 free => 124,
                 used => 3913,
                },

                {
                 date => '2010-07-01',
                 mountpoint => '/media/hda1',
                 free => 33,
                 used => 3233,
                },
                {
                 date => '2010-07-01',
                 mountpoint => '/media/hda2',
                 free => 412,
                 used => 2500,
                },
                {
                 date => '2010-07-01',
                 mountpoint => '/media/hdc2',
                 free => 342,
                 used => 3273,
                },


               );



 return {
         disk_usage=> \@expectedDiskUsage,
        };

}



sub _consolidationInfoReportFirstRound
{
    my ($mod, $db) = @_;
    lives_ok {
        $mod->consolidateReportInfo()
    }  'Execute consolidateReportInfoFromLogs';



    my $expectedTables = firstRoundExpectedTables();

    my $diskUsage = _allRecords($db, 'test_disk_usage_report', ['date', 'mountpoint']);
    eq_or_diff( $diskUsage, $expectedTables->{disk_usage},
                'checkign  disk usage report');
    _checkLastConsolidationDate($db, 'test_disk_usage_report',
                               $firstRoundTime);

}


sub _prepareSecondRound
{
    my ($db) = @_;


    my @data = (
                # values to replace thos of the p2010-007
                {
                 timestamp => '2010-07-23 17:45:06', # lower bound time
                 mountpoint => '/media/hda1',
                 free => 2347,
                 used => 2373,
                },
                {
                 timestamp => '2010-07-26 09:06:06',
                 mountpoint => '/media/hdc2',
                 free => 707,
                 used => 421,
                },
                {
                 timestamp => '2010-07-30 17:45:05',
                 mountpoint => '/media/hdc2',
                 free => 915,
                 used =>  8089,
                },

                #2010-08 values
                {
                 timestamp => '2010-08-05 03:21:12',
                 mountpoint => '/media/hda1',
                 free => 2347,
                 used => 2373,
                },
                {
                 timestamp => '2010-08-05 06:06:06',
                 mountpoint => '/media/hdc2',
                 free => 2156,
                 used => 33434,
                },
                {
                 timestamp => '2010-08-28 10:45:05', # upper bound
                 mountpoint => '/media/hda1',
                 free => 7332,
                 used => 122,
                },
             );


    foreach my $values (@data) {
        $db->insert('test_disk_usage', $values);
    }
    $db->multiInsert();
}


sub _consolidationInfoReportSecondRound
{
    my ($mod, $db) = @_;

    lives_ok {
        $mod->consolidateReportInfo()
    }  'Execute consolidateReportFromLogs for second time';


    my $expectedTables = firstRoundExpectedTables();


    # add and replace entries
    splice @{ $expectedTables->{disk_usage} }, -3; # there will be a bit of reorder
    push @{ $expectedTables->{disk_usage}}, (
                {
                 date => '2010-07-01',
                 mountpoint => '/media/hda1',
                 free => 2347,
                 used => 2373,
                },
                {
                 date => '2010-07-01',
                 mountpoint => '/media/hda2',
                 free => 412,
                 used => 2500,
                },
                {
                 date => '2010-07-01',
                 mountpoint => '/media/hdc2',
                 free => 915,
                 used =>  8089,
                },


                {
                 date => '2010-08-01',
                 mountpoint => '/media/hda1',
                 free => 7332,
                 used => 122,
                },
                {
                 date => '2010-08-01',
                 mountpoint => '/media/hdc2',
                 free => 2156,
                 used => 33434,
                },


                                       );


    my $diskUsage = _allRecords($db, 'test_disk_usage_report', ['date', 'mountpoint']);
    eq_or_diff( $diskUsage, $expectedTables->{disk_usage},
                'checkign  disk usage report');
    _checkLastConsolidationDate($db, 'test_disk_usage_report',
                               $secondRoundTime);


}

sub _allRecords
{
    my ($db, $table, $order) = @_;
    my $orderBy = 'ORDER BY ' . join ', ', @{ $order};
    my $query = "select * from $table $orderBy";
    return $db->query($query);
}

sub _checkLastConsolidationDate
{
    my ($db, $table, $expected) = @_;

    my $query = "select last_date FROM report_consolidation WHERE report_table='$table';";
    my $result = $db->query($query);
    my $lastDateField = $result->[0]->{'last_date'};
    # discard time less than opne second
    my ($lastDate) = split '\.', $lastDateField;

    is $lastDate, $expected,
        "Checking last consolidation date for table $table";
}


sub _setFixedTime
{
    my ($time) = @_;


    my ($date, $hour) = split '\s+', $time;
    my $formatedTime = $date . 'T' . $hour . 'Z';
    Test::MockTime::set_fixed_time($formatedTime);
    my $ts = time();
#    diag "Fixed time: $ts";
}





1;


__DATA__
