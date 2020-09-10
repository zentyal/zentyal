# Copyright (C) 2012-2013 Zentyal S.L.
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
use strict;
use warnings;

# Class: EBox::SysInfo::Model::SmartAdminReportSettings
#
#   This model is used to manage the system status report feature
#
package EBox::SysInfo::Model::SmartAdminReportSettings;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Sudo;
use EBox::Types::Text;
use EBox::Types::Select;
use EBox::Types::MailAddress;
use EBox::View::Customizer;
use EBox::Validate;
use EBox::Exceptions::NotConnected;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use File::Basename;
use TryCatch;

# Group: Public methods

# Constructor: new
#
#       Create the new SmartAdminReportSettings model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::SysInfo::Model::SmartAdminReportSettings> - the recently created model
#
sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless ( $self, $class );

    return $self;
}

# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader = (
       
        new EBox::Types::Select(
           fieldName     => 'start',
           printableName => __('Smart Admin system status report process starts at'),
           editable      => 1,
           populate      => \&_startingTime,
        ),
        new EBox::Types::MailAddress(
            'fieldName' => 'email',
            'printableName' => __('Destination mail account'),
            'size' => '30',
            'optional' => 1,
            'editable' => 1,
        ),
    );

    my $dataTable =
    {
        tableName          => 'SmartAdminReportSettings',
        printableTableName => __('System status report settings'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        messages           => {
            update => __('System Status Report configuration updated')
        },
        modelDomain        => 'SysInfo',
        help               => __('Here you have can schedule the report generation.'),
    };

    return $dataTable;
}

# Method: crontabStrings
#
#       Builds the crontab line for full and incremental.
#
# Returns:
#
#       Hash ref:
#
#               full => scheduling crontab lines for full backup
#               incremental => scheduling crontab lines for incremental backup
#               once        => scheduling crontab lines for full backup once mode
#
#       Note that, it only returns the scheduling part '30 1 * * * *' and not
#       the command
#
sub crontabStrings
{
    my ($self) = @_;

    my $time = $self->row()->valueByName('start');
    my $email = $self->row()->valueByName('email');
    my $once = _crontabString($time);
    my $strings = {
                    once => $once,
                    mail => $email
                };

    return $strings;
}

sub _startingTime
{
    my @time;

    for my $hour (0 .. 23) {
        my $string = sprintf("%02d", $hour) . ':00';
        push (@time,
            {
                value => $hour,
                printableValue => $string,
            }
        );
    }

    return \@time;
}

sub _crontabMinute
{
    return 0;
}

sub _crontabString
{
    my ($hour) = @_;

    my $minute  = _crontabMinute();
    my $weekDay = '*';
    my $monthDay = '*';
    my $month = '*';

    return ["$minute $hour $monthDay $month $weekDay"];
}

1;
