# Copyright (C) 2011 eBox Technologies S.L.
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

package EBox::CaptivePortal::Model::Users;

# Class: EBox::CaptivePortal::Model::Users
#
#   Captive portal currently logged users
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::HostIP;
use EBox::Types::Action;
use EBox::Exceptions::Internal;
use EBox::Exceptions::Lock;
use EBox::CaptivePortal::Auth;

use Fcntl qw(:flock);
use YAML::XS;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->{bwmonitor} = EBox::Global->modInstance('bwmonitor');

    $self->{bwmonitor_enabled} = defined($self->{bwmonitor}) and
                                 $self->{bwmonitor}->isEnabled();


    my $global = EBox::Global->getInstance(1);
    $self->{captiveportal} = $global->modInstance('captiveportal');

    my $model = $self->{captiveportal}->model('BWSettings');
    my $period = $model->defaultQuotaPeriodValue();

    if ($period eq 'day') {
        $self->{period} = 3600*24;
        $self->{period_name} = __('Day bandwidth usage (MB)')
    }
    if ($period eq 'week') {
        $self->{period} = 3600*24*7;
        $self->{period_name} = __('Week bandwidth usage (MB)')
    }

    if ($period eq 'month') {
        $self->{period} = 3600*24*30;
        $self->{period_name} = __('Month bandwidth usage (MB)')
    }


    bless($self, $class);
    return $self;
}

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableHeader = (
        new EBox::Types::Text(
            'fieldName' => 'sid',
            'printableName' => 'sid',
            'hidden' => 1,
            'unique' => 1,
        ),
        new EBox::Types::Text(
            'fieldName' => 'user',
            'printableName' => __('User'),
            'editable' => 0,
        ),
        new EBox::Types::Text(
            'fieldName' => 'time',
            'printableName' => __('Time'),
            'editable' => 0,
            'hidden' => 1,
        ),
        new EBox::Types::HostIP(
            'fieldName' => 'ip',
            'printableName' => __('IP address'),
            'editable' => 0,
        ),
        new EBox::Types::Text(
            'fieldName' => 'mac',
            'printableName' => __('MAC address'),
            'editable' => 0,
            'hidden' => 1,
            'optional' => 1,
        ),
    );

    my @customActions = (
        new EBox::Types::Action(
            name => 'kick',
            printableValue => __('Kick user'),
            model => $self,
            handler => \&_kickUser,
            message => __('Finish user session in Captive Portal'),
            image => '/data/images/deny-active.gif',
        ),
    );

    if ($self->_bwmonitor()) {
        push (@tableHeader, new EBox::Types::Int(
            'fieldName' => 'bwusage',
            'printableName' => $self->{period_name},
            'editable' => 0,
            'optional' => 0)
        );
    }

    my $dataTable =
    {
        tableName          => 'Users',
        printableTableName => __('Current users'),
        printableRowName   => __('user'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        customActions      => \@customActions,
        help               => __('List of current logged in users.'),
        modelDomain        => 'CaptivePortal',
        defaultEnabledValue => 0,
    };

    return $dataTable;
}


sub precondition
{
    return EBox::Global->modInstance('captiveportal')->isEnabled();
}

sub preconditionFailMsg
{
    return __('Captive portal must be enabled in order to see current users list.');
}


# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
#   Populate table with users data
#
sub syncRows
{
    my ($self, $currentRows)  = @_;

    # Get current users array
    my $sidFile;
    my $sessions = {};
    for my $sess_file (glob(EBox::CaptivePortal->SIDS_DIR . '*')) {
        unless (open ($sidFile,  $sess_file)) {
            throw EBox::Exceptions::Internal("Could not open $sess_file");
        }
        # Lock in shared mode for reading
        flock($sidFile, LOCK_SH)
          or throw EBox::Exceptions::Lock('EBox::CaptivePortal::Auth');

        my $sess_info = join('', <$sidFile>);
        my $data = YAML::XS::Load($sess_info);

        # Release the lock
        flock($sidFile, LOCK_UN);
        close($sidFile);

        if (defined($data)) {
            $sessions->{$data->{sid}} = $data;
        }
    }

    # Update table removing, adding and updating users
    my %currentSessions =
        map { $self->row($_)->valueByName('sid') => $_ } @{$currentRows};

    my @sessionsToAdd = grep { not exists $currentSessions{$_} } keys %$sessions;
    my @sessionsToDel = grep { not exists $sessions->{$_} } keys %currentSessions;
    my @sessionsToModify = grep { exists $sessions->{$_} } keys %currentSessions;

    unless (@sessionsToAdd + @sessionsToDel + @sessionsToModify) {
        return 0;
    }

    foreach my $sid (@sessionsToAdd) {
        my @user;

        my $user = $sessions->{$sid}->{user};
        push (@user, sid => $sid);
        push (@user, user => $user);
        push (@user, time => $sessions->{$sid}->{time});
        push (@user, ip => $sessions->{$sid}->{ip});
        push (@user, mac => $sessions->{$sid}->{mac});

        if ($self->_bwmonitor()) {
            push (@user, bwusage => $self->_bwusage($user));
        }

        $self->add(@user);
    }

    foreach my $sid (@sessionsToDel) {
        my $id = $currentSessions{$sid};
        $self->removeRow($id, 1);
    }

    foreach my $sid (@sessionsToModify) {
        my $id = $currentSessions{$sid};
        my $row = $self->row($id);
        my $time = $sessions->{$sid}->{time};
        my $ip = $sessions->{$sid}->{ip};
        my $user = $sessions->{$sid}->{user};
        $row->elementByName('time')->setValue($time);
        $row->elementByName('ip')->setValue($ip);
        if ($self->_bwmonitor()) {
            $row->elementByName('bwusage')->setValue($self->_bwusage($user));
        }
        $row->store();
    }

    return 1;
}

sub _kickUser
{
    my ($self, $action, $id, %params) = @_;

    my $row = $self->row($id);
    my $sid = $row->valueByName('sid');
    my $ip = $row->valueByName('ip');
    my $username= $row->valueByName('user');

    # End session
    EBox::CaptivePortal::Auth::updateSession($sid, $ip, 0);

    # notify captive daemon
    system('cat ' . EBox::CaptivePortal->LOGOUT_FILE);

    $self->setMessage(__x('Closing session for user {user}.', user => $username), 'note');
}


# return 1 if bwmonitor is enabled
sub _bwmonitor
{
    my ($self) = @_;
    return $self->{bwmonitor_enabled};
}


# BW usage for configured period
sub _bwusage
{
    my ($self, $user) = @_;

    my $since = time() - $self->{period};
    return int($self->{bwmonitor}->userExtBWUsage($user, $since) / (1024*1024));
}


1;
