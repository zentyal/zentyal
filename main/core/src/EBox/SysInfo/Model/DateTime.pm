# Copyright (C) 2012 eBox Technologies S.L.
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

# Class: EBox::SysInfo::Model::DateTime
#
#   This model is used to configure the system date time
#

package EBox::SysInfo::Model::DateTime;

use strict;
use warnings;

use Error qw(:try);

use EBox::Gettext;
use EBox::Types::Date;
use EBox::Types::Time;

use base 'EBox::Model::DataForm';

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

# my $ntp = EBox::Global->modInstance('ntp');
#   my $ntpsync = (defined ($ntp) and ($ntp->isEnabled) and ($ntp->synchronized()));
#   my $disabled = $ntpsync ? 'disabled="disabled"' : '';
#% if ($ntpsync) {
#        <div class='help'>
#            <% __('As the NTP synchronization with external servers is enabled, you cannot change the date or time.') %>
#        </div>

sub _table
{
    my ($self) = @_;

    my @tableHead = (new EBox::Types::Date( fieldName      => 'date',
                                            #printableValue => __('Date'),
                                            editable       => 1),

                     new EBox::Types::Time( fieldName      => 'time',
                                            printableValue => __('Time'),
                                            editable       => 1,
                                            help           => __('A change in the date or time will cause all Zentyal services to be restarted.')));

    my $dataTable =
    {
        'tableName' => 'DateTime',
        'printableTableName' => __('Date and time'),
        'modelDomain' => 'SysInfo',
        'defaultActions' => [ 'editField' ],
        'tableDescription' => \@tableHead,
    };

    return $dataTable;
}

# Method: formSubmitted
#
# Overrides:
#
#   <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
{
    my ($self) = @_;

    #my $sysinfo= EBox::Global->modInstance('sysinfo');

    #$self->_requireParam('day', __('Day'));
    #$self->_requireParam('month', __('Month'));
    #$self->_requireParam('year', __('Year'));
    #$self->_requireParam('hour', __('Hour'));
    #$self->_requireParam('minute', __('Minutes'));
    #$self->_requireParam('second', __('Seconds'));

    #my $day = $self->param('day');
    #my $month = $self->param('month');
    #my $year = $self->param('year');
    #my $hour = $self->param('hour');
    #my $minute = $self->param('minute');
    #my $second = $self->param('second');

    #$sysinfo->setNewDate($day, $month, $year, $hour, $minute, $second);

    #my $audit = EBox::Global->modInstance('audit');
    #my $dateStr = "$year/$month/$day $hour:$minute:$second";
    #$audit->logAction('System', 'General', 'changeDateTime', $dateStr);
}

1;
