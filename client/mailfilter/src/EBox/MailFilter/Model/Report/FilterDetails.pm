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

package EBox::MailFilter::Model::Report::FilterDetails;
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
            clean => {
                      printableName => __('clean messages'),
                     },
            spam  => {
                      printableName => __('spam'),
                     },
            banned  => {
                      printableName => __('banned files'),
                     },
            infected  => {
                      printableName => __('infected'),
                     },
            'bad_header'  => {
                      printableName => __('bad header'),
                     },
            blacklisted  => {
                      printableName => __('blacklisted'),
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
                                          fieldName => 'clean', 
                                          printableName =>  __('clean messages'),
                                          editable => 0,
                                         ),
                    new EBox::Types::Int(
                                          fieldName => 'infected',
                                          printableName =>  __('infected'),
                                          editable => 0,
                                         ),
                     new EBox::Types::Int(
                                          fieldName => 'spam',
                                          printableName =>  __('spam'),
                                          editable => 0,
                                         ),
                     new EBox::Types::Int(
                                          fieldName => 'banned',
                                          printableName =>  __('banned files'),
                                          editable => 0,
                                         ),
 
                     new EBox::Types::Int(
                                          fieldName => 'blacklisted',
                                          printableName =>  __('blacklisted senders'),
                                          editable => 0,
                                         ),
                     new EBox::Types::Int(
                                          fieldName => 'bad_header',
                                          printableName =>  __('bad message header'),
                                          editable => 0,
                                         ),

                    ];


     
    my $dataTable = 
        { 
            'tableName' =>__PACKAGE__->tableName(),
            'printableTableName' => __('Filter traffic details'),
            'defaultController' => '/ebox/Mail/Controller/FilterTraffic',
            'defaultActions' => [ 'changeView', 'editField' ],
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
    return 'mailfilter_traffic';
}

sub tableName
{
    return 'FilterDetails';
}


sub timePeriodModelPath
{
    return '/mailfilter/FilterReportOptions';
}


1;
