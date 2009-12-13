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


package EBox::Events::Model::Report::EventsGraph;
use base 'EBox::Logs::Model::Report::Graph';
#
use strict;
use warnings;

use EBox::Gettext;



use Error qw(:try);

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless $self, $class;
    return $self;

}


sub dbTableName
{
    return 'events_accummulated';
}

sub dbFields
{
   my ($package) = @_;

   return  {
            info => { printableName =>  __('Informative'), },
            warn => { printableName =>  __('Warning'), },
            error => { printableName =>  __('Error'), },
            fatal => { printableName =>  __('Fatal error'), },
           };
}

sub altText
{
    return __('Events summarized chart');
}

# Method: _table
#
#       The table description which consists of three fields:
#

#       You can only edit enabled and configuration fields. The event
#       name and description are read-only fields.
#
sub _table
{

  my $dataTable = {
                   tableDescription => [],
                   tableName          => 'EventsGraph',
                   printableTableName => __('Events summarized graph'),

                   modelDomain        => 'Events',
                   #         help               => __(''),

                   defaultActions => [
                                     'editField',
                                     'changeView',
                                    ],

                   messages => {
                                'add'       => undef,
                                'del'       => undef,
                                'update'    => undef,
                                'moveUp'    => undef,
                                'moveDown'  => undef,
                               }
                  };


  return $dataTable;
}





sub tableName
{
    return 'EventsGraph';
}




sub timePeriod
{
    my ($self) = @_;

    my $model = $self->{gconfmodule}->reportOptionsModel();
    my $row = $model->row();

    return $row->valueByName('timePeriod');

}

sub reportRows
{
    my ($self) = @_;

    my %totalRowsByDate;
    
    my $rows =  $self->SUPER::reportRows();
    foreach my $row (@{ $rows } ) {
        my $date = $row->{date};
        if (exists $totalRowsByDate{$date}) {
            $totalRowsByDate{$date}->{info} += $row->{info};
            $totalRowsByDate{$date}->{warn} += $row->{warn};
            $totalRowsByDate{$date}->{error} += $row->{error};
            $totalRowsByDate{$date}->{fatal} += $row->{fatal};
        } else {
            $totalRowsByDate{$date} = $row;
        }
    }

    my @totalRows;
    my @dates = sort keys %totalRowsByDate;
    foreach my $date (@dates) {
        push @totalRows, delete $totalRowsByDate{$date};
    }

    return \@totalRows;
}

# Overriden bz in this case limit = normal limit * sources of events
sub limitByTimePeriod
{
    my ($self) = @_;
    my $unityLimit = $self->SUPER::limitByTimePeriod();

    my $nSources;
    my $dbEngine =  EBox::DBEngineFactory::DBEngine();

    my $timePeriod = $self->timePeriod();
    my $table  = $self->dbTable($timePeriod) ;

    my $query = "SELECT COUNT(DISTINCT(source))  FROM $table";
    my $dbRows = $dbEngine->do($query);

    if ($nSources == 0) {
        $nSources = 1;
    } 

    return $unityLimit * $nSources;
}

1;
