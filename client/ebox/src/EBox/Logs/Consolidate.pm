# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::Logs::Consolidate;

use strict;
use warnings;

use EBox::Global;
use EBox::DBEngineFactory;

use Time::Piece;
use Time::Seconds;


use constant TIME_PERIODS => qw(hourly daily weekly monthly);

# Method: consolidate
#
#          consolidate data tables
#
#   Parameters:
#        modName - name of the module to consolidate or 'all' to consolidate 
#                  all modules
sub consolidate
{
    my ($self, $modName) = @_;

    my @modNames;
    if ($modName eq 'all') {
        @modNames = @{  $self->_allModulesWithConsolidation() };
    }
    else {
        if (not EBox::Global->modInstance($modName)->isEnabled()) {
            return;
        }
        @modNames = ( $modName );
    }

    
    

    foreach my $name (@modNames) {
        my @tableInfos = @{ $self->_tableInfosFromMod($name) };
        foreach my $tableInfo (@tableInfos) {

            while (my ($destTable, $configuration) = each %{ $tableInfo->{consolidate} }) {
                my @timePeriods = TIME_PERIODS;
                
                my $firstTimePeriod = shift @timePeriods;
                
                
                $self->_consolidateTable(
                                         destinationTable => $destTable,
                                         configuration    => $configuration,
                                         
                                         tableInfo        => $tableInfo,
                                         
                                         timePeriod       => $firstTimePeriod,
                                        );
                

                my $prevTimePeriod = $firstTimePeriod;
                foreach my $timePeriod (@timePeriods) {
                    $self->_reconsolidateTable(
                                     destinationTable => $destTable,
                                     configuration    => $configuration,
                                     
                                     timePeriod       => $timePeriod,
                                     sourceTimePeriod => $prevTimePeriod,

                                              );
                    
                    $prevTimePeriod = $timePeriod;
                }

            }
            
        }
    }


}


# Method: timePeriods
#
# Returns:
#  reference to a list of time periods used for consolidation
sub timePeriods
{
    return [ TIME_PERIODS ];
}

sub checkTimePeriod
{
    my ($self, $timePeriod) = @_;

    if (grep { $_ eq $timePeriod }  TIME_PERIODS) {
        throw EBox::Exceptions::Internal( "inexistent time period: $_" );
    }
}



sub _allModulesWithConsolidation
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();


    my @modNames;
    my @mods =  @{  $global->modInstancesOfType('EBox::LogObserver')  };

    foreach my $mod (@mods) {
        if (not $mod->isEnabled()) {
            next;
        }

        my $name = $mod->name();

        my $consolidate = @{  $self->_tableInfosFromMod($name, 1) };
        if (not $consolidate) {
            next;
        }

        push @modNames, $name;
    }



    return \@modNames;
}

sub _consolidateTable
{
    my ($self, %args) = @_;
    my $destinationTable = $args{destinationTable};
    my $tableInfo       = $args{tableInfo};
    my $timePeriod       = $args{timePeriod};
    my $conf             = $args{configuration};

    my $table =   $destinationTable . '_' . $timePeriod;


    my $sourceTable  = $tableInfo->{tablename};;

    
    my $dateCol = $tableInfo->{timecol};
    my $consDateSub = "_$timePeriod" . 'Date';

    my %consColumns = %{ $self->_columnsSpec($conf->{consolidateColumns}) };

    my %accummulateColumns; 
    if (exists $conf->{accummulateColumns} ) {
        %accummulateColumns =   %{  $conf->{accummulateColumns} };
    }
    else {
        %accummulateColumns =  (count => 1);
    }


    my $filterSub = $conf->{filter};

    my $dbengine = EBox::DBEngineFactory::DBEngine();

    my $tsGetRows = time();
    my $rows_r = $self->_sourceRows($dbengine, $sourceTable, $dateCol);

   foreach my $row (@{ $rows_r }) {
       # filter out bad rows
       if ($filterSub) {
           $filterSub->($row) or
               next;
       }

       my %consRow;
       my %accummulator = %accummulateColumns;
       

       while (my ($column, $value) = each %{ $row}) {
           if ($column eq $dateCol) {
               $consRow{date} = $self->$consDateSub($value);
               next;
           }

           exists $consColumns{$column} or
               next;

           my $dest      = $consColumns{$column}->{destination};
      
           my $accummulateColumn = undef;
           if ( $consColumns{$column}->{accummulate}) {
               $accummulateColumn = $consColumns{$column}->{accummulate}->($value, $row);
           }


           my $conversor = $consColumns{$column}->{conversor};
           my $consValue = $conversor->($value, $row);
           
           if (not defined $accummulateColumn) {
               $consRow{$dest} = $consValue;
           }
           else {
               # XXX TODO replace the warning with a die when we will be able to
               # do a rollback
               exists $accummulator{$accummulateColumn} or
                   EBox::warning("Accummulatin in $accummulateColumn which was not defined as accummulate column");
               $accummulator{$accummulateColumn} += $consValue;
           }

        }
       
        $self->_addConsolidatedRow($dbengine, $table, 
                                   \%consRow, 
                                   \%accummulator);
    }

    $self->_clearRows(
                      dbengine => $dbengine, 
                      table    => $sourceTable, 
                      dateCol  => $dateCol, 
                      time     => $tsGetRows,
                      timePeriod => $timePeriod,
                     );
}


sub _reconsolidateTable
{
    my ($self, %args) = @_;
    my $destinationTable = $args{destinationTable};
    my $timePeriod       = $args{timePeriod};
    my $sourceTimePeriod = $args{sourceTimePeriod};
    my $conf             = $args{configuration};

    my $table       = $destinationTable . '_' . $timePeriod;
    my $sourceTable = $destinationTable . '_' . $sourceTimePeriod;
    
    my $dateCol = 'date';
    my $consDateSub = "_$timePeriod" . 'Date';

    my %accummulateColumns; 
    if (exists $conf->{accummulateColumns} ) {
        %accummulateColumns =    map {
            ($_ => 0)
        } keys %{  $conf->{accummulateColumns} };
    }
    else {
        %accummulateColumns =  (count => 0);
    }



    my $dbengine = EBox::DBEngineFactory::DBEngine();

    my $tsGetRows = time();
    my $rows_r = $self->_sourceRows($dbengine, $sourceTable, $dateCol);

   foreach my $row (@{ $rows_r }) {
       my %consRow;
       my %accummulator = %accummulateColumns;
       

       while (my ($column, $value) = each %{ $row}) {
           if ($column eq $dateCol) {
               $consRow{date} = $self->$consDateSub($value);
               next;
           }

           if (exists $accummulator{$column}) {
               $accummulator{$column} = $value;
           }
           else {
               $consRow{$column} = $value;
           }

        }
       
        $self->_addConsolidatedRow($dbengine, $table, 
                                   \%consRow, 
                                   \%accummulator);
    }

    $self->_clearRows(
                      dbengine => $dbengine, 
                      table    => $sourceTable, 
                      dateCol  => $dateCol, 
                      time     => $tsGetRows,
                      timePeriod => $timePeriod,
                     );
}



my $identitySub_r = sub { return $_[0]  };

sub _columnsSpec
{
    my ($self, $consolidateColumns) = @_;
    my %spec = ();

    while (my ($column, $oldSpec) = each %{ $consolidateColumns }) {
        my $newSpec = {};

        if (ref $oldSpec eq 'CODE') {
            $newSpec->{conversor} = $oldSpec;
        }
        elsif (ref $oldSpec eq 'HASH') {
            $newSpec = $oldSpec;
        }
        elsif (not ref $oldSpec) {
            if ($oldSpec != 1) {
                $newSpec->{dest} = $oldSpec;
                
            }
        }

        exists $newSpec->{destination} or
            $newSpec->{destination} = $column;
        exists $newSpec->{conversor} or
            $newSpec->{conversor} = $identitySub_r;
      
        if (exists $newSpec->{accummulate}) {
            my $accummulate=  $newSpec->{accummulate};
            my $refType = ref $accummulate;
            if (not $refType) {
                $newSpec->{accummulate} = sub { return $accummulate };
            }
            elsif (not $refType eq 'CODE')  {
                throw EBox::Exceptions::Internal(
                   "Bad reference type for accummulate field: $refType"
                                                );
            }
            
        } 
        else {
            $newSpec->{accummulate} = undef;
        }


        $spec{$column} =  $newSpec;
    }

    
    return \%spec;
}



my %ttlByTimePeriod = (
                       monthly => 0,
                       weekly => 0,
                       daily => 0,
                       
                       # XXX DEBUG!
                       hourly => 0,
#                       hourly => 3600*48,
                      );

sub _clearRows
{
    my ($self, %params) = @_;
    my $timePeriod = $params{timePeriod};
    my $ttl        = $ttlByTimePeriod{$timePeriod};
    if ($ttl == 0) {
        return;
    }

    my $dbengine = $params{dbengine};
    my $table    = $params{table};
    my $dateCol  = $params{dateCol};
    my $time     = $params{time};


    my $deadline = $time - $ttl;

    my  ($sec,$min,$hour,$mday,$mon,$year) = localtime($deadline);
    $year += 1900;
    $mon +=1;
    my $deadlineDate = "$year-$mon-$mday $hour:$min:$sec";

    my $deleteStatement = 
          "DELETE FROM $table WHERE $dateCol < '$deadlineDate'";


    $dbengine->do($deleteStatement);
}

sub _tableInfosFromMod
{
    my ($self, $modName, $noThrowsException) = @_;
    defined $noThrowsException or
        $noThrowsException = 0;

    my $mod = EBox::Global->modInstance($modName);
    if (not $mod->isa('EBox::LogObserver')) {
        throw EBox::Exceptions::Internal("Module $modName has not log capabilities");
    }


    my @tableInfos;
    my $ti = $mod->tableInfo();

    if (ref $ti eq 'HASH') {
        EBox::warn('tableInfo() in ' . $mod->name .  
                   'must return a reference to a list of hashes not the hash itself');
        @tableInfos = ( $ti );
    }
    else {
        @tableInfos = @{ $ti };
    }

    
    @tableInfos = grep { exists $_->{consolidate} } @tableInfos;

    if (not @tableInfos and (not $noThrowsException)) {
        throw EBox::Exceptions::Internal("Module $modName has not any table with consolidate configuration");
    }

    return \@tableInfos;
}


sub _monthlyDate
{
    my ($self, $timeStamp) = @_;

    $timeStamp =~ s/\-\d\d?\s\d\d?:\d\d?:\d\d?$/-01 00:00:00/;
    return $timeStamp;
}


sub _weeklyDate
{
    my ($self, $timeStamp) = @_;

    my ($datePart) = split '\s', $timeStamp;
    my $t = Time::Piece->strptime($datePart, "%Y-%m-%d");


    my $dweek = $t->day_of_week;

    my $monday;

    my $daysToMonday;
    if ($dweek == 0) { # 0 == sunday
        $daysToMonday = 6;
    }
    else {
        $daysToMonday = $dweek - 1; # monday is day nubmer one;
    }

    $t -= $daysToMonday * ONE_DAY; 

    
    return  $t->year() .'-'. $t->mon() . '-' . $t->mday() . ' 00:00:00';
}


sub _dailyDate
{
    my ($self, $timeStamp) = @_;

    $timeStamp =~ s/\d\d?:\d\d?:\d\d?$/00:00:00/;
    return $timeStamp;
}


sub _hourlyDate
{
    my ($self, $timeStamp) = @_;

     $timeStamp =~ s/\:\d\d?:\d\d?$/:00:00/;
    return $timeStamp; 
}



sub _addConsolidatedRow
{
    my ($self, $dbengine, $table, $row, $accummulator_r) = @_;



    my $setPortion = '';
    while (my ($column, $amount) = each %{ $accummulator_r }) {
        if ($amount == 0) {
            next;
        }
        
        $setPortion .= "$column = $column + $amount,";
    }
    $setPortion =~ s/,$//; # remove last comma

    if (not $setPortion) {
        # add a idle update just to avoid failure and get the rows count
        my ($field) = keys %{ $row };
        $setPortion = " $field = $field ";
    }

    my $wherePortion = '(';
    while (my ($col, $value) = each %{ $row }) {
        $wherePortion .= "$col = '$value' AND ";
    }
    $wherePortion =~ s/ AND $//; # remove last AND
    $wherePortion .= ')';


    my $updateStatement = "UPDATE $table SET $setPortion WHERE $wherePortion";
    

    my $res = $dbengine->do($updateStatement);


    # if there is not a line for the consolidate values the update statement will
    # return 0 and we must do the insert
    if ($res == 0) {
    while (my ($column, $amount) = each %{ $accummulator_r }) {
        if ($amount == 0) {
            next;
        }

        $row->{$column} = $amount;
    }


        $dbengine->insert($table, $row);
    }

}




sub _sourceRows
{
    my ($self, $dbengine, $table, $dateCol) = @_;
    defined $dateCol or
        $dateCol = 'date';

    my $select = "SELECT * FROM $table  ORDER BY $dateCol ";

    my $lastConsolidationDate = $self->_lastConsolidationDate($dbengine, $table);
    if (defined $lastConsolidationDate) {
        $select .= " WHERE $dateCol > $lastConsolidationDate";
    }


    my $res = $dbengine->query($select);

    $self->_updateLastConsolidationDate($dbengine, $table, $res, $dateCol);


    return $res;
}


sub _lastConsolidationDate
{
    my ($self, $dbengine, $table) = @_;

    my $select = "SELECT * FROM consolidation WHERE consolidatedTable = '$table'";
    my $res = $dbengine->query($select);

    my @rows = @{ $res };

    if (@rows == 0) {
        return undef;
    }
    elsif (@rows > 1) {
        throw EBox::Exceptions::Internal(
          "More than one result for lastConsolidationDate for $table"
                                        );
    }

    return $rows[0]->{lastDate};

}

sub _updateLastConsolidationDate
{
    my ($self, $dbengine, $table, $res, $dateCol) = @_;

    if ( @{ $res } == 0) {
        return;
    }

    my $lastRow = $res->[-1];



    my $lastDate = $lastRow->{$dateCol};


    my $updateSt = "UPDATE consolidation SET lastDate ='$lastDate' " .
                   "WHERE consolidatedTable = '$table'";

    
    my $updateRes = $dbengine->do($updateSt);
    if ($updateRes == 0) {
        my $row = {  lastDate => $lastDate, consolidatedTable => $table  };
        $dbengine->insert('consolidation', $row);
    }
}

1;
