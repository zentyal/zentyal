# Copyright (C) 2007 Warp Networks S.L.
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



package EBox::MailFilter::Model::FreshclamStatus;
use base 'EBox::Model::DataForm::ReadOnly';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Boolean;



# eBox exceptions used 
use EBox::Exceptions::External;

sub new 
{
    my $class = shift @_ ;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}


# Method:  _table
#
# This method overrides <EBox::Model::DataTable::_table> to return
# a table model description.
#
# 
sub _table
{
    my @tableDesc = 
        ( 
         new EBox::Types::Text(
                              fieldName => 'message',
                              printableName => __('Status'),
                             ),
         new EBox::Types::Text(
                                fieldName => 'date',
                                printableName => __('Date'),
                               ),


        );

      my $dataForm = {
                      tableName          => __PACKAGE__->nameFromClass(),
                      printableTableName => __('Antivirus database update status'),
                      modelDomain        => 'MailFilter',
                      tableDescription   => \@tableDesc,

                     };



    return $dataForm;
}









# Method: _content
#
#  Provides the content to the fields
#
# Overrides:
#
#     <EBox::Model::DataForm::Readonly::_content>
sub _content
{
    my ($self) = @_;

    my $mailfilter = EBox::Global->modInstance('mailfilter');
    my $state      = $mailfilter->antivirus()->freshclamState;

    my $date          = delete $state->{date};
    
    my $event;
    my $eventInfo;
    if (defined $date) {


        # select which event is active if a event has happened
        while (($event, $eventInfo) = each %{ $state } ) {
            if ($eventInfo) {
                last;
            }
        }         
    }
    else {
        $event = 'uninitialized';
        $date = time();
    }

    # build appropiate msg
    my $msg;
    if ($event eq 'uninitialized')  {
        $msg = __(q{The antivirus database has not been updated since the  mailfilter eBox's module was installed});
    }
    elsif ($event eq 'error') {
        $msg = __('The last update failed');
    }
    elsif ($event eq 'outdated') {
        my $version = $eventInfo;
        $msg = __x("Update failed.\n" .
                      'Your version of freshclam  is outdated.' .
                      'Please, install version {version} or higher',
                      version => $version,
                     );
    }
    elsif ($event eq 'update') {
        $msg = __('Last update successful');
    }
    else {
        $msg = __x('Unknown event {event}', event => $event, );
    }

    my $printableDate =  _formatDate($date);
    return {
            message => $msg,
            date => $printableDate,
           }
}


sub _formatDate
{
    my ($date) = @_;
    my $localDate = localtime($date);
    
    return $localDate;
}

1;

