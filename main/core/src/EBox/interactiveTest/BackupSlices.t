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


use EBox;
use EBox::Sudo;
use EBox::PgDBEngine;
use EBox::Logs::SlicedBackup;
use Error qw(:try);
use Test::More qw(no_plan);
use Test::Exception;
use DateTime;
use Time::Local;

diag ("This test must be run in a complete Zentyal environment. DONT RUN IN A PRODUCTION ENVIRONMENT");

EBox::init();

my $dbengine = EBox::PgDBEngine->new();
my $backupDir = "/tmp/backup-slices.d";
my $backupDirIn3Slice = "/tmp/in3slice-backup-slices.d";
my $archiveDir =  "/tmp/backup-slices-archive.dd";
my $table = 'testslices';

_clearDir($backupDir);
_clearDir($backupDirIn3Slice);
_clearDir($archiveDir);
EBox::Sudo::root("chmod a+rx $archiveDir");
_clearTables($dbengine, $table);

my $period = '10 days';
my $periodInEpoch = EBox::Logs::SlicedBackup::_periodToEpoch($dbengine, $period);
my $nowTs  = _tsToEpoch('2010-01-01 04:45:42');  # no important at this point
my $timeline = 1;
#my $maxId    = _maxArchiveIdInTimeline($dbengine, $timeline, $toDate);
# check that no slices are made with a empty table


my @actualSlice;

@actualSlice = EBox::Logs::SlicedBackup::_actualTableSlice($dbengine, $table, $periodInEpoch, $nowTs);
is @actualSlice, 0, 'Checkign that actualSlice returns empty';


my $sqlGetSlices = "select * from backup_slices where tablename = '$table'";
my $res = $dbengine->query($sqlGetSlices);
is @{ $res}, 0, 'Check that no entries were made for a empty table';

# Rationale: slkice1 and slice 2 adjacents, slice 3 not-adjacent with 2
# a 4th empty partition
my @slice1Timestamps = (
                        '2010-04-20 10:45:12',
                        '2010-04-24 21:21:12',
                        '2010-04-30 10:45:12',
                       );
my @slice2Timestamps = (
                        '2010-04-30 10:45:13',
                        '2010-05-03 21:21:12',
                        '2010-05-08 04:45:41',
                       );

my @slice3Timestamps = (
                        '2010-05-18 06:11:11',
                        '2010-05-19 04:11:11',
                       );


# isnert vlaue into test table
_insertTsAndValue($dbengine, $table, \@slice1Timestamps, 1);
_insertTsAndValue($dbengine, $table, \@slice2Timestamps, 2);
_insertTsAndValue($dbengine, $table, \@slice3Timestamps, 3);

# makgni a backup in the 3 slcie to be used in later test of restore toDate
my $nowFor3SliceBackup =  '2010-05-19 05:12:12';
my $nowTsFor3SliceBackup =  _tsToEpoch($nowFor3SliceBackup);

$dbengine->backupDB($backupDirIn3Slice, 'basaename', slicedMode => 1, nowTs => $nowTsFor3SliceBackup);

# moving time to 4th slice
$nowTs  = _tsToEpoch('2010-05-30 04:45:42');  
@actualSlice = EBox::Logs::SlicedBackup::_actualTableSlice($dbengine, $table, $periodInEpoch, $nowTs);
is_deeply [@actualSlice], 
    [4, '2010-05-20 10:45:15', '2010-05-30 10:45:15', 1], 
    'Checkign that actualSlice returns he valeus for the fourth active one';




$res = $dbengine->query($sqlGetSlices);
is @{ $res}, 4, 'Check that sql rows count is ok';

@actualSlice = EBox::Logs::SlicedBackup::_actualTableSlice($dbengine, $table, $periodInEpoch, $nowTs);
is_deeply [@actualSlice], 
    [4, '2010-05-20 10:45:15', '2010-05-30 10:45:15', 1], 
    'Checkign that actualSlice is stable';




# moving nowTs to a new period to see if new slices are created
$nowTs  = _tsToEpoch('2010-06-4 04:45:42'); 

@actualSlice = EBox::Logs::SlicedBackup::_actualTableSlice($dbengine, $table, $periodInEpoch, $nowTs);
is_deeply [@actualSlice], 
    [5, '2010-05-30 10:45:16', '2010-06-09 10:45:16', 1], 
    'Checking that a new slice has been created';
# insert some data for this time slice
my @slice5Timestamps = (
                        '2010-06-2 5:5:5'
                       );
_insertTsAndValue($dbengine, $table, \@slice5Timestamps, 5);
_checkMaxSlice($dbengine, $table, $timeline, 5);

# do the actual backup

$dbengine->backupDB($backupDir, 'basaename', slicedMode => 1, nowTs => $nowTs);
_checkMaxSlice($dbengine, $table, $timeline, 5);
_checkSlices({ mustExist => 1, compressed => 0 }, $backupDir, $table, $timeline, 5);
_checkSlices(0, $backupDir, $table, $timeline, 1, 2, 3, 4);

# 
is EBox::Logs::SlicedBackup::_noStoredSlices($dbengine, $timeline, 5), 4,
    'see the backup has not archived itself any slice';


# check purge threshodl with no archives
_checkLimitPurgeThreshold($dbengine, $table,  '2010-05-04 21:21:12', 'Tue Apr 20 10:45:11 2010'); # in slice 2
_checkLimitPurgeThreshold($dbengine, $table,  '2010-06-2 10:10:10', 'Tue Apr 20 10:45:11 2010' ); # in slice 5


# restore without archive
_deleteTable($dbengine, $table);
dies_ok {
    $dbengine->restoreDB($backupDir, 'basename',  slicedMode => 1, archiveDir => $archiveDir);
} 'by defualt restore with all archived tables is not allowed';

lives_ok {
    $dbengine->restoreDB($backupDir, 'basename',  slicedMode => 1, archiveDir => $archiveDir, notArchivedForce => 1);
} 'forcing restore even when are not archived tables';


# since we havent archive only the last slice (5) should be restored
_checkDataFromSlices($dbengine, $table, { 5 => 1 });
_checkActualTimeline($dbengine, 1);

# regenate DB for archive tests
_regenerateAllDatabase($dbengine, $table, $timeline);



diag 'archive';
EBox::Logs::SlicedBackup::archive($dbengine,
                         archiveDir => $archiveDir,
                         nowTs      => $nowTs,
                         limit => 10000,
                        );

_checkSlices(0, $archiveDir, $table, $timeline, 5);
_checkSlices(1, $archiveDir, $table, $timeline, 1, 2, 3, 4);
_checkMarkAsArchived(0, $dbengine, $table, $timeline, 5);
_checkMarkAsArchived(1, $dbengine, $table, $timeline, 1, 2, 3, 4);

# slcie 2 is archived so not limitation in purge threshold
_checkLimitPurgeThreshold($dbengine, $table, '2010-05-04 21:21:12','2010-05-04 21:21:12',);

# slcie 5 not archived so limitation
_checkLimitPurgeThreshold($dbengine, $table,  '2010-06-2 10:10:10', 'Sun May 30 10:45:15 2010' );

diag 'retry archive to see that is stable';
EBox::Logs::SlicedBackup::archive($dbengine,
                         archiveDir => $archiveDir,
                         nowTs      => $nowTs,
                         limit => 10000,
                        );
_checkSlices(0, $archiveDir, $table, $timeline, 5);
_checkSlices(1, $archiveDir, $table, $timeline, 1, 2, 3, 4);
_checkMarkAsArchived(0, $dbengine, $table, $timeline, 5);
_checkMarkAsArchived(1, $dbengine, $table, $timeline, 1, 2, 3, 4);


diag 'file retrieval from archive test' ;
my @archiveFiles = sort @{ EBox::Logs::SlicedBackup::slicesFromArchive($dbengine, $archiveDir, $timeline) };
my @expectedFiles = sort map {
    EBox::Logs::SlicedBackup::_backupFileForTable($archiveDir, $table, $timeline, $_) . '.gz'
                 } (1, 2, 3, 4);

is_deeply \@archiveFiles, \@expectedFiles,
    "Checkign retireval files on the archive";


diag ' restore with archive';
my $dataFromAllSlices= {
                       1 => 3,
                       2 => 3,
                       3 => 2,
                       5 => 1,
                      };

_deleteTable($dbengine, $table);
$dbengine->restoreDB($backupDir, 'basename', slicedMode => 1,
                         archiveDir => $archiveDir);
# since we have restored with archive all data should be there (slcie 4 has not
# dato so is not in the list)
_checkDataFromSlices($dbengine, $table, $dataFromAllSlices);


# we will restore and check again to assure restore is stable
$dbengine->restoreDB($backupDir, 'basename', slicedMode => 1,
                         archiveDir => $archiveDir);
_checkDataFromSlices($dbengine, $table, $dataFromAllSlices);
_checkActualTimeline($dbengine, 1);


# now with up to date limit..

# slices up to time
@archiveFiles = sort @{ EBox::Logs::SlicedBackup::slicesFromArchive($dbengine, $archiveDir, $timeline, $nowTsFor3SliceBackup ) };
@expectedFiles = sort map {
    EBox::Logs::SlicedBackup::_backupFileForTable($archiveDir, $table, $timeline, $_) . '.gz'
                 } (1, 2);

is_deeply \@archiveFiles, \@expectedFiles,
    "Checkign retrieval files on the archive up time";



# restore up  to time
$dbengine->restoreDB($backupDirIn3Slice, 'basename', slicedMode => 1,
                         archiveDir => $archiveDir,
                         toDate => $nowTsFor3SliceBackup
                    );

my $dataForSlicesUpTo3   = {
                       1 => 3,
                       2 => 3,
                       3 => 2
                            };
_checkDataFromSlices($dbengine, $table, $dataForSlicesUpTo3);
_checkDataNoLaterThan($dbengine, $table, $nowTsFor3SliceBackup);
_checkActualTimeline($dbengine, 2);

# restore again up to tiem to check stability
$dbengine->restoreDB($backupDirIn3Slice, 'basename', slicedMode => 1,
                         archiveDir => $archiveDir,
                         toDate => $nowTsFor3SliceBackup
                    );

my $dataForSlicesUpTo3   = {
                       1 => 3,
                       2 => 3,
                       3 => 2
                            };
_checkDataFromSlices($dbengine, $table, $dataForSlicesUpTo3);
_checkDataNoLaterThan($dbengine, $table, $nowTsFor3SliceBackup);
_checkActualTimeline($dbengine, 2);

# restore again without date limit, checking that archvies for other timelines
# are NOT restored
$dbengine->restoreDB($backupDirIn3Slice, 'basename', slicedMode => 1,
                         archiveDir => $archiveDir,
                         toDate => $nowTsFor3SliceBackup
                    );
_checkDataFromSlices($dbengine, $table, $dataForSlicesUpTo3);
_checkDataNoLaterThan($dbengine, $table, $nowTsFor3SliceBackup);
_checkActualTimeline($dbengine, 2);



sub _regenerateAllDatabase
{
    my ($dbengine, $table, $timeline) = @_;
    _insertTsAndValue($dbengine, $table, \@slice1Timestamps, 1);
    _insertTsAndValue($dbengine, $table, \@slice2Timestamps, 2);
    _insertTsAndValue($dbengine, $table, \@slice3Timestamps, 3);
    _insertTsAndValue($dbengine, $table, \@slice5Timestamps, 5);

}

sub _checkDataFromSlices
{
    my ($dbengine, $table, $slices) = @_;
    my $sqlGetData = "select value, COUNT(value) AS count FROM $table GROUP BY VALUE";
    my $res =  $dbengine->query($sqlGetData);
    if (not defined $res) {
        die "Error in SQL $sqlGetData";
    }

    my $allOk = 1;
    my %slicesDataInDB = map { $_->{value} => $_->{count} } @{ $res };
    is_deeply \%slicesDataInDB, $slices,
        "Chekcing data stored for table $table";
}

sub _checkMaxSlice
{
    my ($dbengine, $table, $timeline, $max) = @_;
    my $sqlMaxSlices = "select MAX(id) AS maxid from backup_slices where tablename = '$table' AND timeline = $timeline";
    my ($res) = @{ $dbengine->query($sqlMaxSlices) };
    if (not defined $res) {
        die "Error in SQL $sqlMaxSlices";
    }

    is $res->{maxid}, $max, "check that last slice number for table $table and timeline $timeline is $max";
}


sub _checkSliceNotExistInDB
{
    my ($dbengine, $table, $timeline, $n) = @_;
    my $sqlGetSlices = "select * from backup_slices where tablename = '$table' AND timeline = $timeline AND id = $n";
    my $res = $dbengine->query($sqlGetSlices);
    is @{ $res}, 0, "check slice $n for table $table and timeline $timeline dows not exists";
}


sub _checkMarkAsArchived
{
   my ($archived, $dbengine, $table, $timeline, @slices) = @_;


   my $archivedSql = "SELECT id FROM backup_slices WHERE archived AND " .
                  " tablename = '$table' AND timeline = $timeline";
   my $res = $dbengine->query($archivedSql);
   my @archives = sort map { $_->{id} } @{  $res };
   @slices = sort @slices;

   if ($archived) {
       is_deeply \@archives, \@slices, 'Check archived mark in slices';
   } else {
       my $ok = 1;
       my %slicesInArchive = map { $_ => 1 } @archives;
       foreach my $slice (@slices) {
           if (exists $slicesInArchive{$slice}) {
               fail "$slice of $table was marked as archived";
               $ok = 0;
           }
           
       }
       if ($ok) {
           pass "Slices @slices of table $table were not marked as archived as expected";
       }
       
   }


}

sub _checkSlices
{
    my ($options, $dir, $table, $timeline, @slices) = @_;
    my $mustExist;
    my $compressed = 1;
    if (ref $options) {
        $mustExist = $options->{mustExist};
        $compressed = $options->{compressed};
    } else {
        $mustExist = $options;
    }


    my @filesWanted = map {
        my $f = EBox::Logs::SlicedBackup::_backupFileForTable($dir, $table, $timeline, $_);
        if ($compressed) {
            $f .= '.gz';
        }
        $f
    } @slices;


    foreach my $file (@filesWanted) {
        my $exists = (-e $file);
        if ($mustExist) {
            ok $exists, "Checking that slice file $file exists";
        } else {
            is  $exists, undef,
                "Checking that slice file $file NOT exists";            
        }

        
    }
}


sub _checkLimitPurgeThreshold
{
    my ($dbengine, $table,  $original, $expectedAfterLimit) = @_;
    my $final = EBox::Logs::SlicedBackup::limitPurgeThreshold(
                                                                      $dbengine,
                                                                      $table,
                                                                      $original,

                                                                     );
    is $final, $expectedAfterLimit,
        "Checking limitPurgeThreshold for threshold $original";

}

sub _checkDataNoLaterThan
{
    my ($dbengine, $table, $date) = @_;
    my $query = "SELECT COUNT(*) AS count, to_timestamp($date) AS human FROM $table WHERE timestamp > to_timestamp($date)";
    my ($res) = @{ $dbengine->query($query) };
    my $human = $res->{human};
    is $res->{count}, 0, "checking that no record later than $human for $table";

}

sub _checkActualTimeline
{
    my ($dbengine, $wanted) = @_;
    my $actual =   EBox::Logs::SlicedBackup::_activeTimeline($dbengine);
    is $actual, $wanted, 'checking timeline';
}

sub _deleteTable
{
     my ($dbengine, $table) = @_;
     $dbengine->do("DELETE FROM $table");

}

sub _clearTables
{
    my ($dbengine, $table) = @_;
    # prepare table
    try  {
        $dbengine->do("drop table $table");
    } otherwise {};

    $dbengine->do("CREATE TABLE $table (timestamp TIMESTAMP, value INT )");
    $dbengine->do("DELETE FROM backup_slices WHERE tablename='$table'");


}

sub _clearDir
{
    my ($dir) = @_;
    system "rm -rf $dir";
    system "mkdir -p $dir";

}
sub _insertTsAndValue
{
    my ($dbengine, $table, $tsList, $value) = @_;
    foreach my $ts (@{ $tsList}) {
        $dbengine->unbufferedInsert($table, { timestamp => "'$ts'", value => $value} );
    }
    
}


sub _tsToEpoch
{
    my ($ts) = @_;
    my ($year,$mon,$mday, $hour, $min, $sec) = 
        $ts =~ m/(\d+)-(\d+)-(\d+)\s+(\d+):(\d+):(\d+)/;

    # perl lcoatiem adjsutments
    $mon -= 1;
    $year -= 1900;


    my $time = timelocal($sec,$min,$hour,$mday,$mon, $year);
    return $time;
}


sub _epochToTs
{
    my ($epoch) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
                                                    localtime($epoch);
    $mon += 1;
    $year += 1900;
    return "$year-$mon-$mday $hour:$min:$sec";
}

1;
