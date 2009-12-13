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

package EBox::Events::Model::Report::EventsDetails;
use base 'EBox::Logs::Model::Report::Details';

#

use strict;
use warnings;

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::Int;

sub new
{
    my $class = shift @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

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
            source => { printableName => __('Source'), },
            info => { printableName =>  __('Informative'), },
            warn => { printableName =>  __('Warning'), },
            error => { printableName =>  __('Error'), },
            fatal => { printableName =>  __('Fatal error'), },
           };
}





sub _table
{
    
    my $tableHead = [
                     new EBox::Types::Text(
                         'fieldName' => 'date',
                         'printableName' => __('Date'),
                         'size' => '12',
                         editable => 0,
                        ),
                     new EBox::Types::Text(
                         'fieldName' => 'source',
                         'printableName' => __('Source'),
                         'size' => '12',
                         editable => 0,
                        ),
                     new EBox::Types::Int(
                         fieldName => 'info',
                         printableName => __('Informative'), 
                        ),
                     new EBox::Types::Int(
                         fieldName => 'warn',
                         printableName =>  __('Warning'), 
                        ),
                     new EBox::Types::Int(
                         fieldName => 'error',
                         printableName =>  __('Error'), 
                        ),
                     new EBox::Types::Int(
                         fieldName => 'fatal', 
                         'printableName' => __('Fatal error'), 
                        ),
                    ];



    my $dataTable =
        {
            'tableName' =>__PACKAGE__->tableName(),
            'printableTableName' => __('Events details'),
            'defaultActions' => [ 'changeView', 'editField' ],
        'defaultController' =>
         '/ebox/Events/Controller/EventsReport',
            'tableDescription' => $tableHead,
            'class' => 'dataTable',
            'order' => 0,
            'rowUnique' => 0,
            'printableRowName' => __('event'),
            'sortedBy' => 'date',
        };

    return $dataTable;
}



sub tableName
{
    return 'EventsDetails';
}


sub timePeriod
{
    my ($self) = @_;


    my $model = $self->{gconfmodule}->reportOptionsModel();
    my $row = $model->row();

    return $row->valueByName('timePeriod');

}

1;
