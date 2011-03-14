# Copyright (C) 2009-2010 eBox Technologies S.L.
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

package EBox::Mail::Model::Report::TrafficDetails;
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
    return 'mail_message_traffic';
}

sub dbFields
{
   my ($package) = @_;

   return  {
            vdomain => { printableName =>  __('Virtual domain'), },
            sent => { printableName =>  __('Sent messsages'), },
            received => { printableName =>  __('Received messages'), },
            rejected => { printableName =>  __('Rejected messages'), },
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
                         'fieldName' => 'vdomain',
                         'printableName' => __('Virtual domain'),
                         'size' => '12',
                         editable => 0,
                        ),
                     new EBox::Types::Int(
                         fieldName => 'sent',
                         printableName => __('Sent messages'),
                        ),
                     new EBox::Types::Int(
                         fieldName => 'received',
                         printableName =>  __('Received messages'),
                        ),
                     new EBox::Types::Int(
                         fieldName => 'rejected',
                         printableName =>  __('Rejected messages'),
                        ),
                    ];



    my $dataTable =
        {
            'tableName' =>__PACKAGE__->tableName(),
            'printableTableName' => __('Mail traffic details'),
            'defaultActions' => [ 'changeView', 'editField' ],
            'defaultController' => '/ebox/Mail/Controller/TrafficDetails',
            'tableDescription' => $tableHead,
            'class' => 'dataTable',
            'order' => 0,
            'rowUnique' => 0,
            'printableRowName' => __('traffic'),
            'sortedBy' => 'date',
        };

    return $dataTable;
}



sub tableName
{
    return 'TrafficDetails';
}


sub timePeriod
{
    my ($self) = @_;


    my $model = $self->{gconfmodule}->model('TrafficReportOptions');
    my $row = $model->row();

    return $row->valueByName('timePeriod');

}

sub _noAggregateFields
{
    return ['vdomain'] ;
}

1;
