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
use EBox::Exceptions::Internal;
use EBox::Exceptions::Lock;

use Fcntl qw(:flock);
use YAML::XS;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );
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

    my $dataTable =
    {
        tableName          => 'Users',
        printableTableName => __('Current users'),
        printableRowName   => __('user'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        help               => __('List of current logged in users.'),
        modelDomain        => 'CaptivePortal',
        defaultEnabledValue => 0,
    };

    return $dataTable;
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
        $self->add(
            sid => $sid,
            user => $sessions->{$sid}->{user},
            time => $sessions->{$sid}->{time},
            ip => $sessions->{$sid}->{ip},
            mac => $sessions->{$sid}->{mac},
        );
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
        $row->elementByName('time')->setValue($time);
        $row->elementByName('ip')->setValue($ip);
        $row->store();
    }

    return 1;
}


1;
