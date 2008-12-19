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

package EBox::MailFilter::Model::Report::POPProxyDetails;
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
            mails => {
                      printableName => __('total messages'),
                     },
            clean => {
                      printableName => __('clean messages'),
                     },
            virus  => {
                      printableName => __('infected messages '),
                     },

            spam  => {
                      printableName => __('spam messages'),
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
                                          fieldName => 'mails', 
                                          printableName =>  __('total messages'),
                                          editable => 0,
                                         ),
                     new EBox::Types::Int(  
                                          fieldName => 'clean', 
                                          printableName =>  __('clean messages'),
                                          editable => 0,
                                         ),
                    new EBox::Types::Int(
                                          fieldName => 'virus',
                                          printableName =>  __('infected messages'),
                                          editable => 0,
                                         ),
                     new EBox::Types::Int(
                                          fieldName => 'spam',
                                          printableName =>  __('spam messages'),
                                          editable => 0,
                                         ),
          

                    ];


     
    my $dataTable = 
        { 
            'tableName' =>__PACKAGE__->tableName(),
            'printableTableName' => __('Transparent POP proxy traffic details'),
            'defaultController' => '/ebox/Mail/Controller/POPProxyTraffic',
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
    return 'pop_proxy_filter_traffic';
}

sub tableName
{
    return 'POPProxyDetails';
}


sub timePeriodModelPath
{
    return '/mailfilter/POPProxyReportOptions';
}


1;
