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

_consolidationReportFirstRound($module, $db);
diag 'Executed consolidation a second time, we will sue the same checks to assure nothing has changed after the consolidation';
_consolidationReportFirstRound($module, $db);


_setFixedTime($secondRoundTime);

_prepareSecondRound($db);
_consolidationReportSecondRound($module, $db);

    # clear any data from previous run
sub _clearDB
{
    my ($db) = @_;

    my @dbTables = ('food_survey', 'food_survey_total_report', 'food_survey_variety_report', 'location_survey', 'food_by_location_report', 'food_by_subject_and_location_report');
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

    my $createTableSql = q{CREATE TABLE food_survey (timestamp TIMESTAMP, subject VARCHAR(40), food VARCHAR(20), amount INT   ); };
    $db->do($createTableSql);

     $createTableSql = q{CREATE TABLE  food_survey_total_report (date DATE, subject VARCHAR(40), food VARCHAR(20), total INT   ); };
    $db->do($createTableSql);

     $createTableSql = q{CREATE TABLE  food_survey_variety_report (date DATE, subject VARCHAR(40), variety INT   ); };
    $db->do($createTableSql);

    my @data = (
                {
                 timestamp => '2009-09-23 10:34:05',
                 subject => 'jack',
                 food => 'ant',
                 amount => 30,
                },
                {
                 timestamp => '2009-12-31 22:34:05',
                 subject => 'elmo',
                 food => 'banana',
                 amount => 5,
                },
                {
                 timestamp => '2010-02-18 22:34:05',
                 subject => 'elmo',
                 food => 'peanut',
                 amount => 1,
                },
                {
                 timestamp => '2010-02-24 12:34:05',
                 subject => 'elmo',
                 food => 'peanut',
                 amount => 4,
                },
                {
                 timestamp => '2010-02-24 22:14:14',
                 subject => 'jenny',
                 food => 'apple skin',
                 amount => 4,
                },
                {
                 timestamp => '2010-07-05 06:06:06',
                 subject => 'elmo',
                 food => 'ant',
                 amount => 4,
                },
                # dupicat enrtry to cchek ther arent problems with that
                {
                 timestamp => '2010-07-05 06:06:06',
                 subject => 'elmo',
                 food => 'ant',
                 amount => 4,
                },
                {
                 timestamp => '2010-07-05 06:06:06',
                 subject => 'jack',
                 food => 'peanut',
                 amount => 7,
                },
                {
                 timestamp => '2010-07-12 09:06:06',
                 subject => 'jack',
                 food => 'bettle',
                 amount => 3,
                },
                # upper time limit value
                {
                 timestamp => '2010-07-23 17:45:05',
                 subject => 'james',
                 food => 'grass',
                 amount => 2,
                },
               );


    foreach my $values (@data) {
        $db->insert('food_survey', $values);
    }
    $db->multiInsert();

    $createTableSql = q{CREATE TABLE location_survey (timestamp TIMESTAMP, subject VARCHAR(40), location VARCHAR(40)  ); };
    $db->do($createTableSql);
     $createTableSql = q{CREATE TABLE  food_by_location_report (date DATE, location VARCHAR(40), food VARCHAR(20), total INT   ); };
    $db->do($createTableSql);



    my @locationData =     (
                {
                 timestamp => '2009-09-23 10:34:05',
                 subject => 'jack',
                 location => 'tree',
                },
                {
                 timestamp => '2009-12-31 22:34:05',
                 subject => 'elmo',
                 location => 'tree',
                },
                {
                 timestamp => '2010-02-18 22:34:05',
                 subject => 'elmo',
                 location => 'lake',
                },
                {
                 timestamp => '2010-02-24 12:34:05',
                 subject => 'elmo',
                 location => 'lake',
                },
                {
                 timestamp => '2010-02-24 22:14:14',
                 subject => 'jenny',
                 location => 'hill',
                },
                {
                 timestamp => '2010-07-05 06:06:06',
                 subject => 'elmo',
                 location => 'tree',
                },

 #                # if we have two entries with the same keys in both tables we
 #                # get duplicates entries i am not sure if this is fixable or
 #                # not..
#                 # However it shouldnt be a common event so we left it as known
#                 limitation

# { timestamp => '2010-07-05 06:06:06', subject => 'elmo',
 #                # location => 'tree', },
                {
                 timestamp => '2010-07-05 06:06:06',
                 subject => 'jack',
                 location => 'lake',
                },
                {
                 timestamp => '2010-07-12 09:06:06',
                 subject => 'jack',
                 location => 'hill',
                },
                # upper time limit value
                {
                 timestamp => '2010-07-23 17:45:05',
                 subject => 'james',
                 location => 'lake',
                },
               );

    foreach my $values (@locationData) {
        $db->insert('location_survey', $values);
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
    $mod->mock('consolidateReportQueries' => \&moduleConsolidateReportQueries);


    return $mod;
}



sub moduleConsolidateReportQueries
{
    return [
              {
             'target_table' => 'food_survey_total_report',
             'query' => {
                         'select' => 'subject,food, sum(amount) as total',
                         'from' => 'food_survey',
                         'group' => 'subject,food',
                        },
              },

            {
             'target_table' => 'food_survey_variety_report',
             'query' => {
                         'select' => 'subject,COUNT (DISTINCT food) as variety',
                         'from' => 'food_survey',
                         'group' => 'subject',
                        },
            },

            {
             'target_table' => 'food_by_location_report',
             'query' => {
                         'select' => 'food,location,SUM(amount) as total',
                         'from' => 'food_survey,location_survey',
                         'where' => 'food_survey.timestamp = location_survey.timestamp AND food_survey.subject = location_survey.subject',
                         'group' => 'food,location',
                        },

            }
           ];

}

sub firstRoundExpectedTables
{
    my @expectedTotals = (
                {
                 date => '2009-09-01',
                 subject => 'jack',
                 food => 'ant',
                 total => 30,
                },
                {
                 date => '2009-12-01',
                 subject => 'elmo',
                 food => 'banana',
                 total => 5,
                },
                {
                 date => '2010-02-01',
                 subject => 'elmo',
                 food => 'peanut',
                 total => 5,
                },

                {
                 date => '2010-02-01',
                 subject => 'jenny',
                 food => 'apple skin',
                 total => 4,
                },
                {
                 date => '2010-07-01',
                 subject => 'elmo',
                 food => 'ant',
                 total => 8,
                },
                {
                 date => '2010-07-01',
                 subject => 'jack',
                 food => 'bettle',
                 total => 3,
                },
                {
                 date => '2010-07-01',
                 subject => 'jack',
                 food => 'peanut',
                 total => 7,
                },

                {
                 date => '2010-07-01',
                 subject => 'james',
                 food => 'grass',
                 total => 2,
                },
               );

    my @expectedVariety = (
                {
                 date => '2009-09-01',
                 subject => 'jack',
                 variety => 1,
                },
                {
                 date => '2009-12-01',
                 subject => 'elmo',
                 variety => 1,
                },
                {
                 date => '2010-02-01',
                 subject => 'elmo',
                 variety => 1,
                },

                {
                 date => '2010-02-01',
                 subject => 'jenny',
                 variety => 1,
                },
                {
                 date => '2010-07-01',
                 subject => 'elmo',
                 variety => 1,
                },
                {
                 date => '2010-07-01',
                 subject => 'jack',
                 variety => 2,
                },


                {
                 date => '2010-07-01',
                 subject => 'james',
                 variety => 1,
                },
                          );


    my @expectedFoodByLocation = (
                {
                 date => '2009-09-01',
                 location => 'tree',
                 food => 'ant',
                 total => 30
                },
                {
                 date => '2009-12-01',
                 location => 'tree',
                 food  => 'banana',
                 total => 5,
                },

                {
                 date => '2010-02-01',
                 location => 'hill',
                 food => 'apple skin',
                 total => 4,
                },
                {
                 date => '2010-02-01',
                 location => 'lake',
                 food     => 'peanut',
                 total => 5,
                },

                {
                 date => '2010-07-01',
                 location => 'hill',
                 food => 'bettle',
                 total => 3,
                },


                {
                 date => '2010-07-01',
                 location => 'lake',
                 food => 'grass',
                 total => 2,
                },
                {
                 date => '2010-07-01',
                 location => 'lake',
                 food => 'peanut',
                 total => 7,
                },
                  {
                 date => '2010-07-01',
                 location => 'tree',
                 food => 'ant',
                 total => 8,
                },



                                 );


 return {
         variety => \@expectedVariety,
         total   => \@expectedTotals,
         foodByLocation => \@expectedFoodByLocation,
        };

}



sub _consolidationReportFirstRound
{
    my ($mod, $db) = @_;
    lives_ok {
        $mod->consolidateReportFromLogs
    }  'Execute consolidateReportFromLogs';



    my $expectedTables = firstRoundExpectedTables();

    my $totals = _allRecords($db, 'food_survey_total_report', ['date', 'subject', 'food']);
    eq_or_diff( $totals, $expectedTables->{total},
                'checkign total by food consolidation');
    _checkLastConsolidationDate($db, 'food_survey_total_report',
                               $firstRoundTime);




    my $variety = _allRecords($db, 'food_survey_variety_report', ['date', 'subject']);
    eq_or_diff( $variety, $expectedTables->{variety},
                'checking variety');
    _checkLastConsolidationDate($db, 'food_survey_variety_report',
                                $firstRoundTime);


    my $foodByLocation = _allRecords($db, 'food_by_location_report', ['date', 'location', 'food']);
    eq_or_diff( $foodByLocation, $expectedTables->{foodByLocation},
                'checking food_by_location');
    _checkLastConsolidationDate($db, 'food_by_location_report',
                                $firstRoundTime);
}

sub _prepareSecondRound
{
    my ($db) = @_;



    my @data = (
                # lower tiem bound limit value!
                {
                 timestamp => '2010-07-23 17:45:06',
                 subject => 'mongo',
                 food => 'butterfly',
                 amount => 6,
                },


                {
                 timestamp => '2010-07-28 10:34:05',
                 subject => 'jack',
                 food => 'ant',
                 amount => 30,
                },
                {
                 timestamp => '2010-07-29 13:54:23',
                 subject => 'jack',
                 food => 'worm',
                 amount => 1,
                },


                # 2010-08
                {
                 timestamp => '2010-08-5 22:34:05',
                 subject => 'jenny',
                 food => 'banana',
                 amount => 5,

                },
                {
                 timestamp => '2010-08-18 22:34:05',
                 subject => 'jenny',
                 food => 'ant',
                 amount => 1,

                },
             );


    foreach my $values (@data) {
        $db->insert('food_survey', $values);
    }
    $db->multiInsert();

    my @locationData = (
                {
                 timestamp => '2010-07-23 17:45:06',
                 subject => 'mongo',
                 location => 'lake'
                },

                # idle subject (doesnt appear in food_survey table'
                {
                 timestamp => '2010-07-23 17:45:06',
                 subject => 'babalish',
                 location => 'asgard',
                },


                {
                 timestamp => '2010-07-28 10:34:05',
                 subject => 'jack',
                 location => 'tree',

                },
                {
                 timestamp => '2010-07-29 13:54:23',
                 subject => 'jack',
                 location => 'bush',
                },
                {
                 timestamp => '2010-08-5 22:34:05',
                 subject => 'jenny',
                 location => 'lake',
                },
                {
                 timestamp => '2010-08-18 22:34:05',
                 subject => 'jenny',
                 location => 'lake',
                },

               );

    foreach my $values (@locationData) {
        $db->insert('location_survey', $values);
    }
    $db->multiInsert();
}


sub _consolidationReportSecondRound
{
    my ($mod, $db) = @_;

    lives_ok {
        $mod->consolidateReportFromLogs()
    }  'Execute consolidateReportFromLogs for second time';


    my $expectedTables = firstRoundExpectedTables();


    # add new entries
    splice @{ $expectedTables->{total} }, -3; # there will be a bit of reorder
    push @{ $expectedTables->{total}}, (
                {
                 date => '2010-07-01',
                 subject => 'jack',
                 food => 'ant',
                 total => 30,
                },
                {
                 date => '2010-07-01',
                 subject => 'jack',
                 food => 'bettle',
                 total => 3,
                },
                {
                 date => '2010-07-01',
                 subject => 'jack',
                 food => 'peanut',
                 total => 7,
                },
                {
                 date => '2010-07-01',
                 subject => 'jack',
                 food => 'worm',
                 total => 1,
                },
                {
                 date => '2010-07-01',
                 subject => 'james',
                 food => 'grass',
                 total => 2,
                },
                {
                 date => '2010-07-01',
                 subject => 'mongo',
                 food => 'butterfly',
                 total => 6,
                },
                {
                 date => '2010-08-01',
                 subject => 'jenny',
                 food => 'ant',
                 total => 1,
                },
                {
                 date => '2010-08-01',
                 subject => 'jenny',
                 food => 'banana',
                 total => 5,
                },

                                       );

    splice @{$expectedTables->{variety}}, -2;
    push @{$expectedTables->{variety}}, (
               {
                 date => '2010-07-01',
                 subject => 'jack',
                 variety => 4,
                },
               {
                 date => '2010-07-01',
                 subject => 'james',
                 variety => 1,
                },
                {
                 date => '2010-07-01',
                 subject => 'mongo',
                 variety => 1,
                },
                {
                 date => '2010-08-01',
                 subject => 'jenny',
                 variety => 2,
                },

                                         );


    splice @{$expectedTables->{foodByLocation}}, -4;
    push @{$expectedTables->{foodByLocation}}, (
                # 2010-07
                {
                 date => '2010-07-01',
                 location => 'bush',
                 food => 'worm',
                 total => 1,
                },
                {
                 date => '2010-07-01',
                 location => 'hill',
                 food => 'bettle',
                 total => 3,
                },
                 {
                 date => '2010-07-01',
                 location => 'lake',
                 food => 'butterfly',
                 total => 6,
                },

                {
                 date => '2010-07-01',
                 location => 'lake',
                 food => 'grass',
                 total => 2,
                },
                {
                 date => '2010-07-01',
                 location => 'lake',
                 food => 'peanut',
                 total => 7,
                },
                {
                 date => '2010-07-01',
                 location => 'tree',
                 food => 'ant',
                 total => 38,
                },

                # 2010-08
                {
                 date => '2010-08-01',
                 location => 'lake',
                 food => 'ant',
                 total => 1,
                },
                {
                 date => '2010-08-01',
                 location => 'lake',
                 food => 'banana',
                 total => 5,
                },
                                               );


    my $totals = _allRecords($db, 'food_survey_total_report', ['date', 'subject', 'food']);
    eq_or_diff( $totals, $expectedTables->{total},
                'checkign total by food consolidation');
    _checkLastConsolidationDate($db, 'food_survey_total_report',
                               $secondRoundTime);




    my $variety = _allRecords($db, 'food_survey_variety_report', ['date', 'subject']);
    eq_or_diff( $variety, $expectedTables->{variety},
                'checking variety');
    _checkLastConsolidationDate($db, 'food_survey_variety_report',
                                $secondRoundTime);

    my $foodByLocation = _allRecords($db, 'food_by_location_report', ['date', 'location', 'food']);
    eq_or_diff( $foodByLocation, $expectedTables->{foodByLocation},
                'checking food_by_location');
    _checkLastConsolidationDate($db, 'food_by_location_report',
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
        "Checking last ocnsolidation date for table $table";
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
