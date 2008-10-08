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

package EBox::Firewall::Model::Report::PacketTrafficDetails;
use base 'EBox::Logs::Model::Report::Details';

#

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

   return  {
            drop => {
                      printableName => __('packets dropped'),
                     },


           }

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
                     new EBox::Types::Int(  
                                          fieldName => 'drop', 
                                          printableName =>  __('Packets dropped'),
                                          editable => 0,
                                         ),


                    ];


     
    my $dataTable = 
        { 
            'tableName' =>__PACKAGE__->tableName(),
            'printableTableName' => __('Packet traffic details'),
            'defaultActions' => [ 'changeView', 'editField' ],
        'defaultController' =>
         '/ebox/Firewall/Controller/PacketTrafficReport',
            'tableDescription' => $tableHead,
            'class' => 'dataTable',
            'order' => 0,
            'rowUnique' => 0,
            'printableRowName' => __('traffic'),
            'sortedBy' => 'date',
        };

    return $dataTable;
}


sub dbTableName
{
    return 'firewall_packet_traffic';
}

sub tableName
{
    return 'PacketTrafficDetails';
}


sub timePeriod
{
    my ($self) = @_;


    my $model = $self->{gconfmodule}->{PacketTrafficReportOptions};
    my $row = $model->row();

    return $row->valueByName('timePeriod');

}

1;
