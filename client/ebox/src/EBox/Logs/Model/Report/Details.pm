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


use strict;
use warnings;

package EBox::Logs::Model::Report::Details;
use base qw(EBox::Model::DataTable EBox::Logs::Model::Report::Base);


use EBox::Gettext;
use Perl6::Junction qw(all);
use Error qw(:try);





sub refreshRows
{
    my ($self, $timePeriod) = @_;

    my $global  = EBox::Global->getInstance();
    my $modName = $self->{gconfmodule}->name();
    
    my $alreadyChanged = $global->modIsChanged($modName);

    try {
        $self->removeAll(1);
        
        my $dbRows = $self->reportRows($timePeriod);
        foreach my $row (@{ $dbRows }) {
            $self->addRow( %{ $row }  );
        }

        $self->_addTotalRow($dbRows);
    }
   finally {
       if (not $alreadyChanged) {
           # unmark module as changed
           $global->modRestarted($modName);
       }
   };

}


# Method: message
#
#   overriden method to ignore add messages, bz we re always adding rows when
#   refreshing 
#
#   Overriden:
#   <EBox::Model::DataTable::message>
sub message
{
    my ($self, $action) = @_;

    if ($action eq 'add') {
        return undef;
    }

    return $self->SUPER::message($action);
}

sub reportRows
{
    my ($self) = @_;
    my $timePeriod = $self->timePeriod();

    my $dbRows = $self->SUPER::reportRows();
    foreach my $row (@{ $dbRows }) {
        $row->{date} = $self->_printableDate($row->{date}, $timePeriod);
    }



    return $dbRows;
}






my %secondsByTimePeriod = (
                           daily => 24*60*60,
                          );

sub _needUpdate
{
    my ($self, $timePeriod) = @_;

    my $last = exists $self->{lastUpdate} ? $self->{lastUpdate} : 0;
                      
    my $now = time();
    
    if ($now <  ($last + $secondsByTimePeriod{$timePeriod} )) {
        return 0;
    }

    $self->{lastUpdate} = $now;
    return 1;
}


sub rows
{
    my ($self, @p) = @_;
    my $timePeriod = $self->timePeriod();

#    we don't cache anything bz we're not sure it is really needed
#    if ( $self->_needUpdate($timePeriod)) {
        $self->refreshRows($timePeriod);
#    }

    return $self->SUPER::rows(@p);
}

# Method: sortedBy
#
#   we override this so by default is sortedBy the field 'date'. It can be changed
#   to other field or to '' in the table definition
sub sortedBy
{
    my ($self) = @_;
    my $sortedBy = $self->table()->{'sortedBy'};
    return 'date' unless ( defined $sortedBy );
    return $sortedBy;
}

sub _tableHead
{
    my ($self, $timePeriod) = @_;

    my @tableHead =
        (
         new EBox::Types::Text(
                    'fieldName' => 'date',
                    'printableName' => $self->printableTimePeriod($timePeriod),
                    'size' => '12',
                              ),
     );

    while (my ($name, $spec) = each %{ $self->dbFields }) {
        my $type = exists $spec->{type} ?
                              $spec->{type} :
                               'EBox::Types::Text';

        my $printableName = exists $spec->{printableName} ?
                                   $spec->{printableName} :
                                       $name;
                                  
        push @tableHead, $type->new(
                                    fieldName => $name,
                                    printableName => $printableName,
                                    editable => 0,

                                   );
    }


    return \@tableHead;

}

sub _tableName
{
    throw EBox::Exceptions::NotImplemented('_tableName');
}

sub Viewer
{
    return '/ajax/tableBodyWithoutActions.mas';
}



sub _addTotalRow
{
    my ($self, $dbRows) = @_;

    my $row = {};
    $row->{date} = __('All');

    my %dbFields = %{  $self->dbFields() };
    while (my ($name, $attr) = each %dbFields) {
        my $total;
        if (exists $attr->{totalSub}) {
            $total = $attr->{totalSub}->($dbRows);
        }
        else {
            $total = 0;
            foreach my $row (@{ $dbRows }) {
                $total += $row->{$name};
            }
        }

        $row->{$name} = $total;
    }

    $self->addRow( %{ $row } );
}

sub _tailoredOrder # (rows)
{
    my ($self, $rows) = @_;

    # Sorted by sortedBy field element if it's given
    my $fieldName = $self->sortedBy();
    $fieldName or
        $fieldName = 'date';
    if (not $self->fieldHeader($fieldName) ) {
        throw EBox::Exceptions::Internal("orderBy field $fieldName does not exist");
    }

    my $allString = __('All');

    my @sortedRows = sort {
        _compareDates($a, $b, $allString);            
    } @{$rows};
    

    return \@sortedRows;
}


sub _compareDates
{
    my ($a, $b, $allString) = @_;

    my $aDate = $a->valueByName('date');
    my $bDate = $b->valueByName('date');
    
    if ($aDate eq $allString) {
        return -1;
    }
    elsif ($bDate eq $allString) {
        return 1;
    }

    my ($aDatePortion, $aTimePortion) = split '\s', $aDate;
    my @aDateParts = split '-', $aDatePortion;

    my ($bDatePortion, $bTimePortion) = split '\s', $bDate;
    my @bDateParts = split '-', $bDatePortion;
    
    while (@aDateParts) {
        my $aP = pop @aDateParts;
        my $bP = pop @bDateParts;
        my $res = $bP <=> $aP;

        if ($res != 0) {
            return $res;
        }
    }

    if (not defined $aTimePortion) {
        return 0;
    }

    return $bTimePortion cmp $aTimePortion;
}

1;
