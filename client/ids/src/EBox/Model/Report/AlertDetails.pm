# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::IDS::Model::Report::AlertDetails;

use base 'EBox::Logs::Model::Report::Details';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Types::Int;

sub new
{
    my $class = shift @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub dbFields
{
    my ($package) = @_;

    return {
        alert => { printableName => __('number of alerts') },
    }

}


sub _table
{
    my $tableHead = [
        new EBox::Types::Text(
                    fieldName => 'date',
                    printableName => __('Date'),
                    size => '12',
                    editable => 0,
                ),
        new EBox::Types::Int(
                    fieldName => 'alert',
                    printableName =>  __('Number of alerts'),
                    editable => 0,
                ),
        ];

    my $dataTable =
    {
        'tableName' =>__PACKAGE__->tableName(),
        'printableTableName' => __('Alert details'),
        'defaultActions' => [ 'changeView', 'editField' ],
        'defaultController' => '/ebox/IDS/Controller/AlertReport',
        'tableDescription' => $tableHead,
        'class' => 'dataTable',
        'order' => 0,
        'rowUnique' => 0,
        'printableRowName' => __('alerts'),
        'sortedBy' => 'date',
    };

    return $dataTable;
}


sub dbTableName
{
    return 'ids_alert';
}

sub tableName
{
    return 'AlertDetails';
}


sub timePeriod
{
    my ($self) = @_;

    my $model = $self->parentModule()->model('AlertReportOptions');
    my $row = $model->row();

    return $row->valueByName('timePeriod');
}

1;
