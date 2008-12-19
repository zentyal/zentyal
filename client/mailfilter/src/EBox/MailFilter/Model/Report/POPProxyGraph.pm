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


package EBox::MailFilter::Model::Report::POPProxyGraph;
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
    return 'pop_proxy_filter_traffic';
}




sub altText
{
    return __('POP proxy graph');
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
                   tableName          => 'POPProxyGraph',
                   printableTableName => __('Transparent POP proxy traffic'),

                   modelDomain        => 'MailFilter',
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


sub timePeriodModelPath
{
    return '/mailfilter/POPProxyReportOptions';
}




1;
