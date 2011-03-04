# Copyright (C) 2010 EBox Technologies S.L.
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


package EBox::Logs::SlicedBackup;

use EBox;
use EBox::PgDBEngine;
use EBox::Config;
use EBox::Gettext;
use EBox::Exceptions::InvalidData;
use File::Basename;
use Error qw(:try);

use constant CONF_FILE => EBox::Config::etc() . '90eboxpglogger.conf';
use constant SLICES_TABLE =>  'backup_slices';
use constant MIN_SLICE_INTERVAL => 86400; # 1 day (in seconds)


sub backupSlicesDBTable
{
    return SLICES_TABLE;
}


# Method: slicedBackup
#
#  Backs up the logs database in sliced mode
#
# Parameters:
#
#  dbengine - database engine
#  dir - directory when the backup files will be left
#  period (named) - duration of the slices (default: from configuration file)
#  nowTs (named) - actual timestamp in epoch seconds. Useful for testing (default: current time)
sub slicedBackup
{
    my ($dbengine, $dir, %params) = @_;

    my $period;
    if (exists $params{period}) {
        $period = delete $params{period};
    } else {
        $period = EBox::Config::configkeyFromFile('eboxlogs_sliced_backup_period',
                                                  CONF_FILE);
    }

    my $epochPeriod = _periodToEpoch($dbengine, $period);

    my $schemaDumpFile = _schemaFile($dir);
    $dbengine->dumpDB($schemaDumpFile, 1);
    _backupTableSlices($dbengine, $dir, $epochPeriod, %params);
}

# Method: slicedRestore
#
#  Restore the logs database in sliced mode
#
# Parameters:
#
#  dbengine - database engine
#  dir - directory when the backup files had to be found
#  notArchivedForce(named) - force to restore even when they are not archived slices (default: from  configuration file)
#  toDate (named) - restore data until this date. Date must be a epoch timestamp. (default: rstore all the available data in the backup)
#  archiveDir (named) - directory where we could found the archived backup slices
#                      (default: from confioguration file)
#  nowTs (named) - actual timestamp in epoch seconds. Useful for testing (default: current time)
sub slicedRestore
{
    my ($dbengine, $dir, %params) = @_;

    my $toDate = $params{toDate};
    my $forceNoSchema = EBox::Config::configkeyFromFile(
                            'eboxlogs_force_not_schema_sliced_restore',
                            CONF_FILE) eq 'yes';

    my $timeline = _activeTimeline($dbengine);

    my $notStored = _noStoredSlices($dbengine, $timeline);
    if ($notStored) {
        my $force;
        if (exists $params{notArchivedForce}) {
            $force = $params{notArchivedForce} ;
        } else {
            my $value =  EBox::Config::configkeyFromFile('eboxlogs_force_not_archived_restore',
                                                  CONF_FILE);
            $force = 'yes' eq (lc $value);
        }

        unless ($force) {
            throw EBox::Exceptions::External(
         __x('There are {n} log slices not stored; wait or force its storage and retry',
             n => $notStored
            )
                                        );
        }
    }

    my $schemaDumpFile = _schemaFile($dir);
    if ($schemaDumpFile and (-e $schemaDumpFile)) {
        $dbengine->restoreDBDump($schemaDumpFile, 1);
    } else {
        if ($forceNoSchema) {
            EBox::error('No schema file found in this backup. Forcing restore without schema restore');
        } else {
            throw EBox::Exceptions::External(
  __x('No schema file found in this backup. Try another date or force restore without schema changing the relevant key in {cf}. Schemas change unfrequently so it oculd be safe to use a older one',
       cf => CONF_FILE)
                                            );
        }
    }

    _restoreTables($dbengine, $dir, %params);
}

sub _schemaFile
{
    my ($dir) = @_;
    return "$dir/db.schema-dump";
}

sub _periodToEpoch
{
    my ($dbengine, $period) = @_;

    $period =~ s/^\s+//;
    $period =~ s/\s+$//;

    my $sql = "select extract (epoch FROM  interval '$period') AS time";
    my ($res) =  @{ $dbengine->query($sql) };
    if (not defined $res) {
        throw EBox::Exceptions::InvalidData(
                                            data => __('Backup slice time interval'),
                                            value => $period,
                                            );
    }

    my $time = $res->{time};
    if ($time < MIN_SLICE_INTERVAL) {
        throw EBox::Exceptions::InvalidData(
                                            data => __('Backup slice time interval'),
                                            value => $period,
                                            advices => "Time interval too small");
    }

    return $res->{time};
}

sub _backupTableSlices
{
    my ($dbengine, $dir, $period, %params) = @_;
    my $nowTs = exists $params{nowTs} ? $params{nowTs}
                                      : time();

    my $superuserTmpDir = _superuserTmpDir();

    my @tables = @{ $dbengine->tables() };

    my $copySqlCmd = '';
    foreach my $table (@tables) {
        my ($n, $startTs, $endTs, $timeline) = _actualTableSlice($dbengine, $table, $period, $nowTs);
        $copySqlCmd .=
            _backupTableSliceCmd($superuserTmpDir, $table, $timeline, $n, $startTs, $endTs);
    }

    _copySqlAsSuperuser($dbengine, $copySqlCmd, $superuserTmpDir, $dir);

    return 1;
}


sub _restoreTables
{
    my ($dbengine, $dir, %params) = @_;
    my $toDate = $params{toDate};
    my $archiveDir = $params{archiveDir};
    # to avoid glob // problems
    $dir =~ s{/+$}{};
    my $tmpDir = EBox::Config::tmp();

    my $actualTimeline = _activeTimeline($dbengine);

    my @tableFiles = glob("$dir/*.table-slice");
    push @tableFiles,
        @{
            EBox::Logs::SlicedBackup::slicesFromArchive($dbengine, $archiveDir, $actualTimeline, $toDate)
          };

    push @tableFiles, glob("$dir/*.table-dump");

    my $copySqlCmd;
    foreach my $file (@tableFiles) {
        EBox::info("Next DB table file: $file");
        my ($basename, $dirname, $extension) = fileparse($file, qr/\.[^.]*/);

        # in slices case basenane is table-number
        my ($table, $timeline, $n) = split '-', $basename, 3;

        if ($table eq SLICES_TABLE) {
            # this table is exempted from backup
            next;
        }

        my $uncompresedFile;
        my $toDelete = undef;
        if ($extension =~ m/\.gz$/) {
            $uncompresedFile = $tmpDir . 'table-tmp';
            my $zcat = "zcat $file > $uncompresedFile";
            system $zcat;
            if ($? != 0) {
                EBox::error(
                  "Unable to decompress file with command $zcat\n".
                  "Skipping slice"
                           );
                next;
            }
            $toDelete = $uncompresedFile;
        } else {
            $uncompresedFile = $file;
        }

        my $copySqlCmd = "COPY $table FROM '$uncompresedFile';\n";
        # to copy from a file must be db superuser
        $dbengine->sqlAsSuperuser(sql => $copySqlCmd);
        EBox::info("$file restored to the DB\n");
        if ($toDelete) {
            unlink $toDelete;
        }
     }

    if ($toDate) {
        _updateTimeline($dbengine, $actualTimeline, $toDate);
    }
}


sub _updateTimeline
{
    my ($dbengine, $actual, $date) = @_;

    my $neededSql = 'SELECT id FROM ' . SLICES_TABLE . ' ' .
                     "WHERE timeline = $actual AND " .
                     "beginTs > to_timestamp($date) LIMIT 1";
    my $res = $dbengine->query($neededSql);
    if (not @{ $res} ) {
        # no new timeline needed..
        return;
    }

    my $new = $actual + 1;
    my $updateTimeline = 'UPDATE ' . SLICES_TABLE . ' ' .
                         "SET TIMELINE=$new " .
                         "WHERE timeline = $actual AND " .
                         "beginTs <= to_timestamp($date)" ;
    $dbengine->do($updateTimeline);
}


# wether a database table should be backed/restored in sliced mode.
# currently are exmpted all the report/consolidation tables, 'admin' and 'backup_slices'
sub _noSliceableTable
{
    my ($table) = @_;

    my $suffix = (split '_', $table)[-1];

    if ($suffix eq 'report') {
        # the report tables are dumped fully
        return 1;
    } elsif (($suffix eq 'hourly') or
             ($suffix eq 'daily') or
             ($suffix eq 'weekly') or
             ($suffix eq 'monthly')
            ) {
        # accumulated tables are not sliceable
        return 1;
    } elsif ($table eq 'consolidation' or ($table eq 'report_consolidation')) {
        return 1;
    } elsif ($table eq 'admin' or ($table eq 'backup_slices')) {
        return 1;
    }

    return 0;
}

sub _actualTableSlice
{
    my ($dbengine, $table, $period, $nowTs) = @_;

    if (_noSliceableTable($table)) {
        return ();
    }

    my $sqlActiveSlice = "SELECT id, beginTs, endTs, timeline FROM backup_slices WHERE tablename = '$table' AND endTs >= to_timestamp($nowTs)  ORDER BY id DESC LIMIT 1";
    my ($res) =  @{ $dbengine->query($sqlActiveSlice) };
    if (not defined $res) {
        # table is empty or last slice is not longer active, create slices
        _updateSliceMap($dbengine, table => $table, period => $period, nowTs => $nowTs);
        # try again wtih the new tables (we use the try again isntead of making
        # return with the new values from _updateSliceMap to avoid to add data
        # conversion code
         ($res) =  @{ $dbengine->query($sqlActiveSlice) };
        if (not defined $res) {
            # no slices
            return ();
        }
    }

    # data from active slice
    return ($res->{id}, $res->{begints},  $res->{endts}, $res->{timeline});
}


sub _activeTimeline
{
    my ($dbengine) = @_;
    my $sql = 'SELECT MAX(timeline) AS timeline FROM backup_slices';
    my ($res) =  @{ $dbengine->query($sql) };
    my $timeline = $res->{timeline};
    if ($timeline) {
        return $timeline;
    }

    return 1; # valeu for first timeline
}


sub _updateSliceMap
{
    my ($dbengine, %params) = @_;
    my $table = $params{table};
    defined $table or
        throw EBox::Exceptions::MissingArgument('table');
    my $period = $params{period};
    defined $period or
        throw EBox::Exceptions::MissingArgument('period');

    # is assummed that nowTs >= all timestamp records which it should be true
    # when time is properly set
    my $nowTs  = $params{nowTs};
    defined $nowTs or
        throw EBox::Exceptions::MissingArgument('nowTs');

    my ($beginTs, $slice, $timeline);
    # first we will try to get them from last active slice
    my $sqlLastSlice = "SELECT id AS slice, EXTRACT (EPOCH FROM endTs) AS end, timeline FROM backup_slices WHERE tablename = '$table'  ORDER BY id DESC LIMIT 1";
    my ($res) =  @{ $dbengine->query($sqlLastSlice) };
    if (defined $res) {
        $beginTs = $res->{end} + 1;
        $slice   = $res->{slice} + 1;
        $timeline = $res->{timeline};
    } else {
        # no slices create first slice
        my $sqlFirstTs = "SELECT EXTRACT (EPOCH FROM timestamp) AS first FROM $table  ORDER BY timestamp ASC LIMIT 1";
        my ($res) =  @{ $dbengine->query($sqlFirstTs) };
        if (not defined $res) {
            # table empty, no creating slices
            return;
        }

        $beginTs = $res->{first};
        $slice = 1;
        $timeline = _activeTimeline($dbengine);
    }

    my $endTs = $beginTs + $period;
    while ($beginTs <= $nowTs) {
        my $sql = qq{INSERT INTO backup_slices ( tablename, id,  beginTs, endTs, timeline, archived) VALUES ('$table', $slice, to_timestamp($beginTs), to_timestamp($endTs),$timeline, FALSE)};
        $dbengine->do($sql);

        # check that next slice has not it begins in the future..
        my $nextSliceBeginTs = $endTs + 1;
        if ( $nextSliceBeginTs <= $nowTs) {
            # update values for next slice
            $slice += 1;
            $beginTs = $nextSliceBeginTs;
            $endTs   = $nextSliceBeginTs + $period;
        } else {
            # break..
            last;
        }
    }
}

# return the uncompressed name (without .gz)
sub _backupTableSliceCmd
{
    my ($dir, $table, $timeline, $n, $beginTs, $endTs) = @_;

    my $outputFile = _backupFileForTable($dir, $table, $timeline, $n);
    my $sqlCommand;
    if (not defined $n) {
        $sqlCommand = qq{COPY $table TO '$outputFile';\n};
    } else {
        my $select = "SELECT * FROM $table WHERE  " .
            qq{timestamp >=  '$beginTs' AND timestamp <= '$endTs'};
        $sqlCommand = qq{COPY ($select) TO '$outputFile';\n};
    }

    return $sqlCommand;
}

sub _backupFileForTable
{
    my ($dir, $table, $timeline, $n) = @_;

    if (defined $n) {
        return lc "$dir/$table-$timeline-$n.table-slice";
    } else {
        return lc "$dir/$table.table-dump";
    }
}


# Method: archive
#
#  Move the data from past slices to the archive. It only archives it,does not purge it
#
#  Parameters:
#   dbengine -
#  archiveDir (named) - directory where we could found the archived backup slices
#                      (default: from configuration file)
#  limit (named) - how many past slices we should move to the archive, this parameter exists for load purposes because this method is executed periodically by cron.    (default: from configuration file)
#  nowTs (named) - actual timestamp in epoch seconds. Useful for testing (default: current time)
sub archive
{
    my ($dbengine, %params) = @_;

    # unroll parameters and check them
    my $limit = exists $params{limit} ?
                 $params{limit} :
                 EBox::Config::configkeyFromFile(
                          'eboxlogs_sliced_backup_archive_at_once',
                           CONF_FILE
                                                );
    ($limit > 0) or
        throw EBox::Exceptions::InvalidData(
                              data => __('Slices to be archived at once'),
                              value => $limit,
                                           );

    my $timeline = exists $params{timeline} ? $params{timeline} : 1;
    ($timeline > 0) or
        throw EBox::Exceptions::InvalidData(
                              data => __('Slices timeline'),
                              value => $timeline,
                                           );

    my $archiveDir = exists $params{archiveDir} ?
                       $params{archiveDir}
                       :  archiveDir();
    my $nowTs = exists $params{nowTs} ? $params{nowTs} : time();

    try {
        $dbengine->commandAsSuperuser("test -d $archiveDir");
    } otherwise {
        throw EBox::Exceptions::External(
                 qq{Directory $archiveDir must be readable by DB's superuser}
                                         );
    };

    # assure we that we haves a updated slicemaps
    my $period =   EBox::Config::configkeyFromFile('eboxlogs_sliced_backup_period',
                                                  CONF_FILE);
    my $epochPeriod = _periodToEpoch($dbengine, $period);
    foreach my $table (@{ archivableTables($dbengine) }) {
        _updateSliceMap($dbengine, table => $table, period => $epochPeriod, nowTs => $nowTs);
    }


    # get slices to backup
    my $sql = 'SELECT id, tablename, beginTs, endTs FROM ' . SLICES_TABLE . ' '.
        " WHERE archived = FALSE AND ".
        " endTs < to_timestamp($nowTs) AND " .
         "TIMELINE = $timeline " .
         "LIMIT $limit";

    my $copyCmds;
    my @toArchive;
    my @outputFiles;
    my $superuserTmpDir = _superuserTmpDir();

    my $res = $dbengine->query($sql);
    foreach my $slice (@{ $res }) {
        my $table = $slice->{tablename};
        my $id    = $slice->{id};
        my $beginTs = $slice->{begints};
        my $endTs = $slice->{endts};
        push @toArchive, [$table, $id];

        my $outputFile = _backupFileForTable($archiveDir, $table, $timeline, $id);
        push @outputFiles, $outputFile;

        $copyCmds .=  _backupTableSliceCmd(
                                           $superuserTmpDir,
                                           $table,
                                           $timeline,
                                           $id,
                                           $beginTs,
                                           $endTs
                                          );
    }

    if (not @toArchive) {
        return;
    }

    _copySqlAsSuperuser($dbengine, $copyCmds, $superuserTmpDir, $archiveDir);

    # mark as archived
    foreach my $arch (@toArchive) {
        my ($table, $id) = @{ $arch };
        my $updateSql = "UPDATE " . SLICES_TABLE . ' ' .
                        "SET archived = TRUE " .
                        "WHERE tablename = '$table' AND " .
                        "id = $id AND "  .
                        "timeline = $timeline";
        $dbengine->do($updateSql);
    }

    # compress files
    foreach my $file (@outputFiles) {
        try {
            EBox::Sudo::root("gzip $file");
        } catch EBox::Exceptions::Command with {
            EBox::error("Cannot compress file $file. Try to do it manully. Skipping to next file.")
        };
    }
}

#  Method: archiveDir
#
#  Returns:
#    the archive directory found in the config file
sub archiveDir
{
    return EBox::Config::configkeyFromFile('eboxlogs_sliced_backup_archive', CONF_FILE);
}

# Method: archivableTables
#
# Returns:
#  list of tables that must be archived
sub archivableTables
{
    my ($dbengine) = @_;
    my @tables = grep {
        not _noSliceableTable($_)
    } @{ $dbengine->tables() };

    return \@tables;
}

# Method: slicedMode
#
# Returns:
#   whether sliced mode is enabled
sub slicedMode
{
    my $value = lc EBox::Config::configkeyFromFile('eboxlogs_sliced_backup', CONF_FILE);
    return $value eq 'yes';
}


# Method: limitPurgeThreshold
#
#   Push back if needed the purge threshold so data form no-archived slices isnt purged
#
#   Parameters:
#      dbengine -
#      table    - table to be purged
#      threshold - purge's threshold, this a date in string format
#
#  Returns:
#    the same threshold if not change is needed, a new one if needed
sub limitPurgeThreshold
{
    my ($dbengine, $table, $threshold) = @_;
    my $query = "SELECT EXTRACT(EPOCH FROM beginTs) AS ts " .
                 "FROM " . SLICES_TABLE . ' ' .
                 "WHERE archived = FALSE AND " .
                 "tablename = '$table' AND" .
                 "((endTs <= '$threshold') OR (beginTs <= '$threshold') )  " .
                 "ORDER BY beginTs ASC  LIMIT 1";
    my ($res) = @{ $dbengine->query($query) };
    if (defined $res) {
        my $newTh = $res->{ts} -1;

        return scalar localtime($newTh);
    }

    # no neccessary to limit..
    return $threshold;
}

# executes a COPY SQL command as db's superuser. The COPY command needs superuser permissions.
sub _copySqlAsSuperuser
{
    my ($dbengine, $copySql, $superuserDir, $dstDir) = @_;

    my $superUser = $dbengine->_dbsuperuser();

    # we need a place where superusers user is able to write
    EBox::Sudo::root("rm -rf $superuserDir");
    mkdir $superuserDir or
        throw EBox::Exceptions::Internal("Cannot mkdir $superuserDir");
    EBox::Sudo::root("chown -R $superUser.$superUser $superuserDir");

    # to copy to a file must be db superuser
    $dbengine->sqlAsSuperuser(sql => $copySql);

    # move files to their final destination
    EBox::Sudo::root("chown -R ebox.ebox $superuserDir");
    EBox::Sudo::root("mv $superuserDir/* $dstDir")
}

sub _superuserTmpDir
{
    return  EBox::Config::tmp() . 'postgres-tmp';
}


# Method: slicesFromArchive
#
#  retrieve the slices from archive directory ehich meets the criteria
#
#  Parameters:
#   dbengine -
#  archiveDir  - directory where we could found the archived backup slices
#   actualTimeline - current timeline
#   toDate  - restore data until this date. Date must be a epoch timestamp. (default: all archives)
#
# Returns:
#  list of archive files pargs
sub slicesFromArchive
{
    my ($dbengine, $archiveDir, $actualTimeline, $toDate) = @_;

    defined $archiveDir or
        $archiveDir = archiveDir();
    $archiveDir =~ s{/+$}{/};

    my @allTableFiles = glob("$archiveDir/*.table-slice.gz");
    my %maxIds = %{ _maxIdsInTimeline($dbengine, $actualTimeline, $toDate) };

    # this is to discard restores from either inadecuate dates or timelines
    my %selected;
    foreach my $file (@allTableFiles) {
        my ($basename, $dirname, $extension) = fileparse($file, qr/\..*/);
        my ($table, $timeline, $n) = split '-', $basename, 3;

        if ($timeline > $actualTimeline) {
            # we should never  restoredfrom a timeline in the future
            next;
        }
        else {
            # check when id is in this timeline
            my $max=  $maxIds{$table};
            if (not defined $max) {
                EBox::warn("Unknow table has backup slices : $table");
                next;
            }

            if ($n > $max) {
                # not applyable to this timeline
                next;
            }
        }

        if (not exists $selected{$table}) {
            # create hash for table
            $selected{$table} = {};
        }

        if ($timeline == $actualTimeline) {
            # actual timeline always have priority even when it is not in slcies
            # data table
            $selected{$table}->{$n} =  {
                                        timeline => $timeline,
                                        file => $file,
                                       };
            next;
        }

        # this is to give priority to more recent timelines..
        if (not exists $selected{$table}->{$n}) {
            # create new entry
            $selected{$table}->{$n} =  {
                                        timeline => $timeline,
                                        file => $file,
                                       };
            next;
        } elsif ($selected{$table}->{$n}->{timeline} < $timeline) {
            # update entry
            $selected{$table}->{$n} =  {
                                        timeline => $timeline,
                                        file => $file,
                                       };
            next;
        }

        # end choose files loop
    }


    my @files = map {
        my $tableValues = $_;
        map {
            $_->{file}
        } values %{ $tableValues };
    } values %selected;

    return \@files;
}

sub _maxIdsInTimeline
{
    my ($dbengine, $timeline, $toDate) = @_;

    my $query = 'SELECT tablename, MAX(id) AS maxid FROM ' . SLICES_TABLE . ' ' .
         " WHERE timeline = $timeline";
    if ($toDate) {
        # restrict by date
        $query .=
        " AND (endTs <= to_timestamp($toDate))";
    }
    $query .= ' GROUP BY tablename';

    my ($res)  =  $dbengine->query($query) ;
    if (not @{ $res }) {
        return undef;
    }

    my %maxIds = map {
        $_->{tablename} => $_->{maxid}
    } @{ $res };

    return \%maxIds;
}

# Method: _noStoredSlices
#
# Parameters:
#   dbengine
#   timeline - current timeline
#
# Returns:
#  the number of past slices which aren't stored
sub _noStoredSlices
{
    my ($dbengine, $timeline) = @_;

    my $query = 'SELECT  SUM(noArchived.amount) As count FROM ' .
        '(SELECT (COUNT(*) -1) AS amount FROM  ' . SLICES_TABLE . ' ' .
         " WHERE archived =FALSE " .
         " AND timeline <= $timeline " .
         ' GROUP BY tablename ' .
          ' ) AS noArchived';

    my ($res)  = @{ $dbengine->query($query) };
    if (not $res) {
        return 0;
    }

    return $res->{count};
}

1;
