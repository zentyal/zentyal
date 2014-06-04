# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::CaptivePortal::Model::Users;

use base 'EBox::Model::DataTable';

# Class: EBox::CaptivePortal::Model::Users
#
#   Captive portal currently logged users
#

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::HostIP;
use EBox::Types::Action;
use EBox::Exceptions::Internal;
use EBox::Exceptions::Lock;
use EBox::CaptivePortal::Middleware::AuthLDAP;
use EBox::Types::Int;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->{bwmonitor} = $self->global()->modInstance('bwmonitor');

    $self->{bwmonitor_enabled} = defined($self->{bwmonitor}) and
                                 $self->{bwmonitor}->isEnabled();

    my $global = EBox::Global->getInstance(1);
    $self->{captiveportal} = $global->modInstance('captiveportal');

    bless($self, $class);
    return $self;
}

sub periodInfo
{
    my ($self) = @_;

    if (exists $self->{periodInfo} and defined $self->{periodInfo}) {
        return $self->{periodInfo};
    }

    my $info = {};

    my $model = $self->{captiveportal}->model('BWSettings');
    my $period = $model->defaultQuotaPeriodValue();

    if ($period eq 'day') {
        $info->{period} = 3600*24;
        $info->{period_name} = __('Day bandwidth usage (MB)')
    } elsif ($period eq 'week') {
        $info->{period} = 3600*24*7;
        $info->{period_name} = __('Week bandwidth usage (MB)')
    } elsif ($period eq 'month') {
        $info->{period} = 3600*24*30;
        $info->{period_name} = __('Month bandwidth usage (MB)')
    } else {
        EBox::error("Unknown period: $period. Using 'day' as default");
        $info->{period} = 3600*24;
        $info->{period_name} = __('Day bandwidth usage (MB)')
    }

    $self->{periodInfo} = $info;
    return $info;
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
        new EBox::Types::Int(
            'fieldName' => 'quotaExtension',
            'printableName' => 'quotaExtension',
            'editable' => 0,
            'hidden' => 1,
            'defaultValue' => 0,
        ),
    );

    my @customActions = (
        new EBox::Types::Action(
            name => 'extend',
            printableValue => __('Extend bandwidth quota'),
            model => $self,
            handler => \&_extendUser,
            message => __('Reset bandwith limit'),
            image => '/data/images/reload-plus.png',

        ),
        new EBox::Types::Action(
            name => 'kick',
            printableValue => __('Kick user'),
            model => $self,
            handler => \&_kickUser,
            message => __('Finish user session in Captive Portal'),
            image => '/data/images/deny-active.gif',
        ),

    );

    if ($self->_bwmonitorEnabled()) {
        push (@tableHeader, new EBox::Types::Int(
            'fieldName' => 'bwusage',
            'printableName' => $self->periodInfo()->{period_name},
            'editable' => 0,
            'optional' => 0)
        );
    }

    my $dataTable =
    {
        tableName          => 'Users',
        printableTableName => __('Current users'),
        printableRowName   => __('user'),
#        defaultActions     => [ 'editField', 'changeView' ],
        defaultActions     => [ 'changeView' ],
        tableDescription   => \@tableHeader,
        customActions      => \@customActions,
        help               => __('List of current logged in users.'),
        modelDomain        => 'CaptivePortal',
        defaultEnabledValue => 0,
        noDataMsg => __('No users logged in'),
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
    for my $session (@{EBox::CaptivePortal::Middleware::AuthLDAP::currentSessions()}) {
        $sessions->{$session->{sid}} = $session;
    }

    # Update table removing, adding and updating users
    my %currentSessions =
        map { $self->row($_)->valueByName('sid') => $_ } @{$currentRows};

    my @sessionsToAdd = grep { not exists $currentSessions{$_} } keys %$sessions;
    my @sessionsToDel = grep { not exists $sessions->{$_} } keys %currentSessions;
    my @sessionsToModify = grep { exists $sessions->{$_} } keys %currentSessions;

    unless (@sessionsToAdd or @sessionsToDel or @sessionsToModify) {
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

        if ($self->_bwmonitorEnabled()) {
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
        if ($self->_bwmonitorEnabled()) {
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
    EBox::CaptivePortal::Middleware::AuthLDAP::updateSession($sid, $ip, 0);

    # notify captive daemon
    system('cat ' . EBox::CaptivePortal->LOGOUT_FILE);

    $self->setMessage(__x('Closing session for user {user}.', user => $username), 'note');
}

sub _extendUser
{
    my ($self, $action, $id, %params) = @_;

    my $row = $self->row($id);
    my $sid = $row->valueByName('sid');
    my $ip = $row->valueByName('ip');
    my $username= $row->valueByName('user');
    my $user = EBox::Global->modInstance('users')->userByUID($username);

    my $quota = $self->parentModule()->{cpldap}->getQuota($user);
    if ($quota == 0) {
        return;
    }

    my $extension = $row->elementByName('quotaExtension');
    my $newValue  =  $extension->value() + $quota;
    $extension->setValue($newValue);
    $row->store();
}

# return 1 if bwmonitor is enabled
sub _bwmonitorEnabled
{
    my ($self) = @_;
    return $self->{bwmonitor_enabled};
}

# BW usage for configured period
sub _bwusage
{
    my ($self, $user) = @_;

    my $since = time() - $self->periodInfo()->{period};
    return int($self->{bwmonitor}->userExtBWUsage($user, $since) / 1048576);
}

sub currentUsers
{
    my ($self) = @_;
    my $ids = $self->ids();
    my @users;
    for my $id (@{$ids}) {
        my $row = $self->row($id);
        my $bwusage = 0;
        my $quotaExtension = 0;

        if ($self->{bwmonitor_enabled}) {
            $bwusage = $row->valueByName('bwusage');
            $quotaExtension = $row->valueByName('quotaExtension');
        }

        push(@users, {
            user => $row->valueByName('user'),
            ip => $row->valueByName('ip'),
            mac => $row->valueByName('mac'),
            sid => $row->valueByName('sid'),
            time => $row->valueByName('time'),
            quotaExtension => $quotaExtension,
            bwusage => $bwusage,
        });
    }

    return \@users;
}

1;
