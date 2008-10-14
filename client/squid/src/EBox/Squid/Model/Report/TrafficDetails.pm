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

package EBox::Squid::Model::Report::TrafficDetails;
use base 'EBox::Logs::Model::Report::Details';

#

use strict;
use warnings;

use EBox::Gettext;


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
        requests => {
                     printableName => __('Requests') 
                    },

        accepted => {
                     printableName => __('Accepted requests') 
                    },

        accepted_size => {
                          printableName => __('Accepted traffic size (Kb)') 
                         },


        denied   => {
                     printableName => __('Denied requests') 
                    },

        denied_size => {
                        printableName => __('Denied traffic size (Kb)') 
                       },


        filtered => {
                     printableName => __('Filtered requests') 
                    },
            
        filtered_size => {
                          printableName => __('Filtered traffic size (Kb))') 
                         },



           }

}




sub _table
{
    my ($class) = @_;

    my $tableHead = [
                     new EBox::Types::Text (
                                            fieldName => 'date',
                                            printableName => __('Date') 
                                           ),
                     new EBox::Types::Text (
                                            fieldName => 'requests',
                                            printableName => __('Requests') 
                                           ),

                     new EBox::Types::Text (
                                            fieldName => 'accepted',
                                            printableName => __('Accepted requests') 
                                           ),

                     new EBox::Types::Text (
                                            fieldName => 'accepted_size',
                                            printableName => __('Accepted traffic size (Kb)') 
                                           ),


                     new EBox::Types::Text ( 
                                            fieldName => 'denied',
                                            printableName => __('Denied requests') 
                                           ),
                     
                     new EBox::Types::Text ( 
                                            fieldName => 'denied_size',
                                            printableName => __('Denied traffic size (Kb)') 
                                           ),


                     new EBox::Types::Text ( 
                                            fieldName => 'filtered',
                                            printableName => __('Filtered requests') 
                                           ),
            
                     new EBox::Types::Text ( 
                                            fieldName => 'filtered_size',
                                            printableName => __('Filtered traffic size (Kb))') 
                                           ),

                    ];

     
    my $dataTable = 
        { 
            'tableName' =>__PACKAGE__->tableName(),
            'printableTableName' => __('Web traffic details'),
#            'pageTitle' => __('Mail traffic'),
            'defaultController' => '/ebox/Mail/Controller/TrafficReport',
            'defaultActions' => [ 'changeView' ],
            'tableDescription' => $tableHead,
            'class' => 'dataTable',
            'order' => 0,
#            'help' => __x('Enable/disable logging per-module basis'),
            'rowUnique' => 0,
            'printableRowName' => __('traffic'),
            'sortedBy' => 'date',
        };

    return $dataTable;
}


sub dbTableName
{
    return 'squid_traffic';
}

sub tableName
{
    return 'TrafficDetails';
}


sub timePeriodModelPath
{
    return '/squid/TrafficReportOptions';
}


1;
