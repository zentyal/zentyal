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

# Class: EBox::SysInfo::Model::SmartAlerts
#
#   This model is used to manage the system status report feature
#
package EBox::SysInfo::Model::SmartAlerts;

use base 'EBox::Model::DataForm';

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Text;

# Group: Public methods

# Constructor: new
#
#       Create the new SmartAlerts model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::SysInfo::Model::SmartAlerts> - the recently created model
#
sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless ( $self, $class );

    return $self;
}

# Method:  _table
#
# This method overrides <EBox::Model::DataTable::_table> to return
# a table model description.
#
# This table is composed of two fields:
#
#   domain (<EBox::Types::Text>)
#   enabled (EBox::Types::Boolean>)
#
# The only avaiable action is edit and only makes sense for 'enabled'.
#
sub _table
{
    my @tableDesc = (
        new EBox::Types::Boolean(
            fieldName     => 'enableRam',
            printableName => __('Enable RAM monitoring'),
            editable      => 1,
            unique        => 1,
        ),
        new EBox::Types::Boolean(
            fieldName     => 'enableDisk',
            printableName => __('Enable free space monitoring'),
            editable      => 1,
            unique        => 1,
        ),
        new EBox::Types::Boolean(
            fieldName     => 'enableCpu',
            printableName => __('Enable CPU monitoring'),
            editable      => 1,
            unique        => 1,
        ),
        new EBox::Types::Text(
            fieldName     => 'telegramId',
            printableName => __("Telegram chat ID"),
            editable      => 1,
            unique        => 0,
            size          => 30,
        ),
        new EBox::Types::Text(
            fieldName     => 'telegramApiToken',
            printableName => __("Telegram Bot API token"),
            editable      => 1,
            unique        => 0,
            size          => 50,
        ),
    );

    my $dataForm = {
        tableName          => __PACKAGE__->nameFromClass(),
        printableTableName => __('Smart alerts settings'),
        modelDomain        => 'SysInfo',
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableDesc,
    };

    return $dataForm;     
}

# Method: crontabStrings
#
#       Builds the crontab line for full and incremental.
#
# Returns:
#
#       Hash ref:
#
#               once        => scheduling crontab lines for kernel management once a day
#
#       Note that, it only returns the scheduling part '30 1 * * * *' and not
#       the command
#
sub crontabStringsRam
{
    my ($self) = @_;

    if ($self->isEnabledRam()) {
        my $once = _crontabString('*', '*/2');
        my $telegram = $self->row()->valueByName('telegramId');
        my $telegramToken = $self->row()->valueByName('telegramApiToken');
        my $strings = {
            once => $once,
            resource => __('RAM'),
            alert_body => __('Your system memory usage is too high! The memory usage is'),
            api_token => $telegramToken,
            telegram => $telegram,
        };

        return $strings;
    } else {
        return 0;
    }
}

sub crontabStringsCpu
{
    my ($self) = @_;

    if ($self->isEnabledCpu()) {
        my $once = _crontabString('*', '*/3');
        my $telegram = $self->row()->valueByName('telegramId');
        my $telegramToken = $self->row()->valueByName('telegramApiToken');
        my $strings = {
            once => $once,
            resource => __('CPU'),
            alert_body => __('Your system CPU usage for the last minute is too high. The CPU usage for the last minute is'),
            api_token => $telegramToken,
            telegram => $telegram,
        };

        return $strings;
    } else {
        return 0;
    }
}

sub crontabStringsDisk
{
    my ($self) = @_;

    if ($self->isEnabledDisk()) {
        my $once = _crontabString('*', '0');
        my $telegram = $self->row()->valueByName('telegramId');
        my $telegramToken = $self->row()->valueByName('telegramApiToken');
        my $strings = {
            once => $once,
            resource => __('DISK'),
            alert_body => __('Available disk free space too lower! The remaining disk space is'),
            api_token => $telegramToken,
            telegram => $telegram,
        };

        return $strings;
    } else {
        return 0;
    }
}

sub isEnabledCpu
{
    my ($self) = @_;
    my $enabled = $self->row()->valueByName('enableCpu');
    
    return $enabled;
}

sub isEnabledRam
{
    my ($self) = @_;
    my $enabled = $self->row()->valueByName('enableRam');
    
    return $enabled;
}

sub isEnabledDisk
{
    my ($self) = @_;
    my $enabled = $self->row()->valueByName('enableDisk');
    
    return $enabled;
}

sub _crontabString
{
    my ($hour, $minute) = @_;

    my $weekDay = '*';
    my $monthDay = '*';
    my $month = '*';

    return ["$minute $hour $monthDay $month $weekDay"];
}

1;
