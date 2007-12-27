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

package EBox::Event::Watcher::RAID;

# Class: EBox::Event::Watcher::RAID
#
#   This class is a watcher which intended to notify about events that
#   may happen at RAID installation.
#
#   The events are the following ones:
#
#   Partition events:
#
#    - Changing its state: active (sync, resync), faulty, spare, remove
#
#   RAID array events:
#
#    - Changing its state: active, degraded, recovering, clean, failed, resync
#
#    - Operation: active with percentage, estimated time to finish and speed
#
#    - Management: addition, removal, failure
#
#   At first time, the RAID event watcher will supply all its initial
#   information as new one.

use base 'EBox::Event::Watcher::Base';

# eBox uses
use EBox::Event;
use EBox::Gettext;
use EBox::Global;
use EBox::Report::RAID;

# Core modules

# Constants
use constant RAID_ARRAY_KEY => 'raid/arrays';

# Group: Public methods

# Constructor: new
#
#        The constructor for <EBox::Event::Watcher::RAID>
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::new>
#
# Parameters:
#
#        - non parameters
#
# Returns:
#
#        <EBox::Event::Watcher::RAID> - the newly created object
#
sub new
  {

      my ($class) = @_;

      my $self = $class->SUPER::new(
                                    period      => 50,
                                    domain      => 'ebox',
                                   );
      bless( $self, $class);

      $self->{events} = EBox::Global->modInstance('events');

      return $self;

  }

# Method: run
#
#        Check if any event has happened to the RAID installation
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::run>
#
# Returns:
#
#        undef - if no services are out of control (Chemical
#        Brothers!)
#
#        array ref - <EBox::Event> an event is sent when some service
#        is out of control
#
sub run
  {

      my ($self) = @_;

      my @events;
      my $raidInfo = EBox::Report::RAID->info();
      foreach my $raidArray (keys %{$raidInfo}) {
          # Skip unused devices
          next if ( $raidArray eq 'unusedDevices' );
          my $eventsRaidArray = $self->_checkRaidArray($raidArray, $raidInfo->{$raidArray});
          if ( defined ($eventsRaidArray) ) {
              push (@events, @{$eventsRaidArray} );
          }
      }
      # Check removed ones

      # Store last info in GConf state if changed
      if ( @events > 0 ) {
          $self->_storeNewRAIDState($raidInfo);
      }

      if ( @events > 0 ) {
          return \@events;
      } else {
          return undef;
      }

  }

# Group: Class static methods

# Method: ConfigurationMethod
#
# Overrides:
#
#       <EBox::Event::Component::ConfigurationMethod>
#
sub ConfigurationMethod
{
    return 'none';
}

# Method: Able
#
# Overrides:
#
#       <EBox::Event::Watcher::Able>
#
sub Able
{
    return EBox::Report::RAID->enabled();
}

# Group: Protected methods

# Method: _name
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::_name>
#
# Returns:
#
#        String - the event watcher name
#
sub _name
  {

      return __('RAID');

  }

# Method: _description
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::_description>
#
# Returns:
#
#        String - the event watcher detailed description
#
sub _description
  {

      return __('Check if any event has happened in RAID subsystem');

  }

# Group: Private methods

# Check any event that may ocurr in the RAID array
sub _checkRaidArray # (arrayRaidName, raidInfo)
{
    my ($self, $arrayRaidName, $raidInfo) = @_;

    my $storedInfo = $self->_storedArrayRaidInfo($arrayRaidName);

    unless ( defined ($storedInfo) ) {
        return $self->_createEventArrayRaid($arrayRaidName, $raidInfo);
    }
    # Check the state
    # Check the devices' number
    # Check the operations
    # Check each RAID device

}

# Check any event that may ocurr in the RAID device
sub _checkRaidComponent # (raidDevInfo)
{
    my ($self, $raidCompInfo) = @_;

    # Check its state

}

# Get stored info from the raid array
sub _storedArrayRaidInfo
{
    my ($self, $arrayRaidName) = @_;

    my $arrayInfoSeqNums = $self->{events}->st_all_dirs_base(RAID_ARRAY_KEY);

    my $matchedStoredInfo;
    foreach my $arraySeqNum ( @{$arrayInfoSeqNums} ) {
        my $arrayName = $self->{events}->st_get_string(RAID_ARRAY_KEY . '/'
                                                       . "$arraySeqNum/name");
        if ( $arrayName eq $arrayRaidName ) {
            $matchedStoredInfo = $self->{events}->st_hash_from_dir(RAID_ARRAY_KEY
                                                                   . "/$arraySeqNum");
        }
    }

    return $matchedStoredInfo;

}

# Create the event from the raid info
sub _createEventArrayRaid # (arrayName, raidInfo)
{

    my ($self, $arrayName, $raidArrayInfo) = @_;

    my $msg = __x('New array RAID device {devName} information:',
                  devName => $arrayName) . '\n';
    $msg .= __x('State: {state}', state => $raidArrayInfo->{state}) . '\n';
    $msg .= __x('Type: {type}', type => $raidArrayInfo->{type}) . '\n';
    $msg .= __x('Active devices needed: {nb}', nb => $raidArrayInfo->{activeDevicesNeeded}) . '\n';
    $msg .= __x('Active devices: {nb}', nb => $raidArrayInfo->{activeDevices}) . '\n';
    unless ( $raidArrayInfo eq 'none' ) {
        $msg .= __x('Operation in progress: {operation}',
                    operation => $raidArrayInfo->{operation}) . '\n';
        $msg .= __x('Completed operation percentage: {per}',
                    per => $raidArrayInfo->{operationPercentage}) . '\n';
        $msg .= __x('Operation estimated finish time: {time}',
                    time => $raidArrayInfo->{operationEstimatedTime}) . '\n';
    }
    while (my ($raidCompNum, $raidCompInfo) = each %{$raidArrayInfo->{raidDevices}}) {
        $msg .= __x('Raid component {nb}: device {device} state {state}',
                    nb => $raidCompNum, device => $raidCompInfo->{device},
                    state => $raidCompInfo->{state}) . '\n';
    }

    my $arrayRaidEvent = new EBox::Event(
                                         level   => 'info',
                                         source  => $self->name(),
                                         message => $msg
                                        );

    return [ $arrayRaidEvent ];

}

# Store last RAID info in GConf state
sub _storeNewRAIDState
{
    my ($self, $raidInfo) = @_;

    my $evMod = $self->{events};
    $evMod->st_delete_dir(RAID_ARRAY_KEY);

    while ( my ($raidArrayName, $raidArrayInfo) = each %{$raidInfo} ) {
        next if ( $raidArrayName eq 'unusedDevices' );
        my $id = $evMod->st_get_unique_id('array', RAID_ARRAY_KEY);
        my $rootKey = RAID_ARRAY_KEY . "/$id/";
        $evMod->st_set_string($rootKey . 'name', $raidArrayName);
        $evMod->st_set_string($rootKey . 'state', $raidArrayInfo->{state});
        $evMod->st_set_int($rootKey . 'deviceNumber', $raidArrayInfo->{activeDevices});
        $evMod->st_set_string($rootKey . 'operation', $raidArrayInfo->{operation});
        if ( $raidArrayInfo->{operation} ne 'none' ) {
            $evMod->st_set_int($rootKey . 'operationAttr/percentage',
                               $raidArrayInfo->{operationPercentage});
            $evMod->st_set_string($rootKey . 'operationAttr/estimatedFinishTime',
                                  $raidArrayInfo->{operationEstimatedTime});
        }
        while (my ($raidCompNum, $raidCompInfo) = each %{$raidArrayInfo->{raidDevices}}) {
            my $compId = $evMod->st_get_unique_id('comp', $rootKey . 'components');
            my $compKey = $rootKey . "components/$compId/";
            $evMod->st_set_string( $compKey . 'device', $raidCompInfo->{device});
            $evMod->st_set_string( $compKey . 'state', $raidCompInfo->{state});
        }
    }

}

1;
