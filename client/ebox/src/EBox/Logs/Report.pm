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

package EBox::Logs::Model::Report;
use base qw(EBox::Model::DataTable);

use EBox::DBEngineFactory;
use EBox::Gettext;
use Perl6::Junction qw(all);


sub allowedTimePeriods
{
    return ['daily'];
}


sub _printableDate
{
    my ($self, $date, $timePeriod) = @_;

    if ($timePeriod eq 'daily') {
        $date =~ s/\d+:.*?$//;
        return $date;
    }
    else {
        throw EBox::Exceptions::Internal("Bad time period: $timePeriod");
    }
}




sub _checkTimePeriod
{
    my ($self, $period) = @_;

    if ($period ne all(@{ $self->allowedTimePeriods })) {
        throw EBox::Exceptions::Internal("No time period $period allowed in the report");
    }

}




sub printableTimePeriod
{
    my ($self, $period) = @_;
    
    if ($period eq 'daily') {
        return  __('Day');
    }
    

    return $period;
}


sub dbTableName
{
    throw EBox::Exceptions::NotImplemented('tableName');
}

sub dbTable
{
    my ($self, $timePeriod) = @_;

    $self->_checkTimePeriod($timePeriod);

    return $self->dbTableName() . '_' . $timePeriod;
}



sub dbFields
{
    throw EBox::Exceptions::NotImplemented('fields');
}



sub refreshRows
{
    my ($self, $timePeriod) = @_;

    $self->removeAll(1);

    my $dbRows = $self->reportRows($timePeriod);
    foreach my $row (@{ $dbRows }) {
            $self->addRow( %{ $row }  );
    }

}


sub reportRows
{
    my ($self, $timePeriod) = @_;

    my $table  = $self->dbTable($timePeriod) ;
    my @fields = keys %{ $self->dbFields()  };

    my $dbEngine =  EBox::DBEngineFactory::DBEngine();

    my $columnsPortion = join ',', ('date', @fields);
    my $query = "SELECT $columnsPortion FROM $table";

    my $dbRows = $dbEngine->query($query);
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
    my ($self, $timePeriod, @p) = @_;

    if ( $self->_needUpdate($timePeriod)) {
        $self->refreshRows($timePeriod);
    }

    return $self->SUPER::rows(@p);
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

    while (my ($name, $spec) = each %{ $self->fields }) {
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

1;
