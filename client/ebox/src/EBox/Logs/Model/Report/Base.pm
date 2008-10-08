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

package EBox::Logs::Model::Report::Base;

use EBox::DBEngineFactory;
use EBox::Gettext;
use Perl6::Junction qw(all);
use Error qw(:try);



sub _printableDate
{
    my ($self, $date, $timePeriod) = @_;
    defined $timePeriod or
        $timePeriod = $self->timePeriod();

    my ($daysPortion, $hoursPortion) = split '\s', $date;
    my ($year, $month, $day) = split '-', $daysPortion;
    my ($hour)               = split ':', $hoursPortion;
    
    if ($timePeriod eq 'hourly') {
        return "$day-$month-$year $hour:00";
    }
    elsif ($timePeriod eq 'daily') {
        return "$day-$month-$year";
    }
    elsif ($timePeriod eq 'weekly') {
        return "$day-$month-$year"; 
    }
    elsif ($timePeriod eq 'monthly') {
        return "$month-$year";
    }
    else {
        throw EBox::Exceptions::Internal("Bad time period: $timePeriod");
    }
}



my $allAllowedTimePeriods = all(qw(hourly daily weekly monthly));
sub _checkTimePeriod
{
    my ($self, $period) = @_;

    if ($period ne $allAllowedTimePeriods) {
        throw EBox::Exceptions::Internal("No time period $period allowed in the report");
    }

}





# Method: dbTableName
#
#  Abstract method to ve overriden.
#
# Returns: 
#    the name of the table used to generate the report minus the time
#       period suffix
sub dbTableName
{
    throw EBox::Exceptions::NotImplemented('dbTableName');
}

# Method: dbTable
#
#  Returns:
#    the specific dbTable that will be used for the time period specified
#
#   Parameters:
#     $timePeriod - the time period 
sub dbTable
{
    my ($self, $timePeriod) = @_;
    defined $timePeriod or
        $timePeriod = $self->timePeriod();

    $self->_checkTimePeriod($timePeriod);

    return $self->dbTableName() . '_' . $timePeriod;
}


# Method: dbFields
#
#    this must be return information about the data base field used for the
#    report.  The information must be returning as a hash ref with the name of
#    the column as key and the following configuration hash ref with this
#    format: 
#              - printableName
#              - totalSub: for the detail table this sub reference will be used
#                           to get the total for the field instead of adding
#                           the values of all rows. The function will be called
#                           passing a reference to all rows.
#      
sub dbFields
{
    throw EBox::Exceptions::NotImplemented('dbFields');
}




# Method: reportRows
#
#   Returns: reference to a list with the rows of the table appropiate to the
#  selected time period
sub reportRows
{
    my ($self) = @_;
    my $timePeriod = $self->timePeriod();

    my $table  = $self->dbTable($timePeriod) ;
    my @fields = keys %{ $self->dbFields()  };

    my $dbEngine =  EBox::DBEngineFactory::DBEngine();

    my $columns = join ',', ('date', @fields);
    my $query = "SELECT $columns FROM $table ORDER BY date ASC";

    my $dbRows = $dbEngine->query($query);

    return $dbRows;
}






# Method: timePeriod
#
#     get the time period active in the report. This is by default done getting
#     the model specied in timePeriodModelPath and its value for the field
#     'timePeriod'. This method should be overriden if the child needs to use a
#     different mechanism to get the time period
sub timePeriod
{
    my ($self) = @_;

    my $modelPath = $self->timePeriodModelPath;

    my $model = $self->{gconfmodule}->model($modelPath);
    my $row = $model->row();

    return $row->valueByName('timePeriod');

}

# Method: timePeriodModelPath
#
#    Abstact method. Used in the default implementation of timePeriod Must
#    return the path of a component with a 'timePeriod' field which reflect the
#    currently selected time period
sub timePeriodModelPath
{
    throw EBox::Exceptions::NotImplemented('timePeriodModelPath');
}

1;
