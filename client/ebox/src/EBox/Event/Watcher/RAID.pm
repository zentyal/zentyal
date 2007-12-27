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
#    - Hot additions and removals
#
#   RAID array events:
#
#    - Changing its state: active, degraded, recovering, clean, failed, resync
#
#    - Number of devices
#
#    - Operation: active with percentage and estimated time to
#    finish. Finish and starting ones.
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
      my $removedArrayEvents = $self->_checkRemoveArray($raidInfo);
      if ( @{$removedArrayEvents} > 0 ) {
          push (@events, @{$removedArrayEvents});
      }

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
    my ($self, $arrayRaidName, $raidArrayInfo) = @_;

    my $storedInfo = $self->_storedArrayRaidInfo($arrayRaidName);

    unless ( defined ($storedInfo) ) {
        return $self->_createEventArrayRaid($arrayRaidName, $raidArrayInfo);
    }

    my @updatedEvents = ();

    # Check the state
    # Check the devices' number
    # Check the operations
    # Check each RAID device
    my @checkSubs = ('_checkArrayStatus', '_checkArrayCompNum', '_checkArrayOp',
                     '_checkComponents');

    foreach my $checkSub (@checkSubs) {
        my $newEvents = $self->$checkSub($arrayRaidName, $raidArrayInfo, $storedInfo);
        if ( defined($newEvents) ) {
            push(@updatedEvents, @{$newEvents});
        }
    }

    return \@updatedEvents;

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
            $matchedStoredInfo->{components}
              = $self->{events}->st_array_from_dir(RAID_ARRAY_KEY . "/$arraySeqNum/components");
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
        while (my ($raidCompNum, $raidCompInfo) = each %{$raidArrayInfo->{raidDevices}}) {
            my $compId = $evMod->st_get_unique_id('comp', $rootKey . 'components');
            my $compKey = $rootKey . "components/$compId/";
            $evMod->st_set_string( $compKey . 'device', $raidCompInfo->{device});
            $evMod->st_set_string( $compKey . 'state', $raidCompInfo->{state});
        }
    }

}

# Check if any of the stored RAID array has dissappeared
sub _checkRemoveArray # (raidInfo)
{
    my ($self, $raidInfo) = @_;

    my $evMod = $self->{events};
    my @removeEvents = ();
    my @currentArrays = grep { $_ ne 'unusedDevices' } keys %{$raidInfo};
    my %currentArrays = map { $_ => 1 } @currentArrays;

    my $dirs = $evMod->st_all_dirs_base(RAID_ARRAY_KEY);
    foreach my $dir (@{$dirs}) {
        my $devName = $evMod->st_get_string(RAID_ARRAY_KEY . "/$dir/name");
        next if ( exists ( $currentArrays{$devName} ));
        my $evtMsg = __x('RAID device {name} has dissappeared: A RAID array '
                         . 'which previously was configured appears to no '
                         . 'longer be configured', name => $devName);
        push( @removeEvents, new EBox::Event(level   => 'info',
                                             source  => $self->name(),
                                             message => $evtMsg));
    }

    return \@removeEvents;

}

# Group: Checkers update in RAID subsystem

# Check if the RAID device status has changed
sub _checkArrayStatus # (arrayName, arrayInfo, storedInfo)
{
    my ($self, $arrayName, $arrayInfo, $storedInfo) = @_;

    if ( $arrayInfo->{state} ne $storedInfo->{state} ) {
        my $evtMsg = __x('RAID device {name} has changed its state '
                         . 'from {oldState} to {newState}',
                         name     => $arrayName,
                         oldState => $self->_i18nState($storedInfo->{state}),
                         newState => $self->_i18nState($arrayInfo->{state}));
        return [ new EBox::Event(level   => 'info',
                                 source  => $self->name(),
                                 message => $evtMsg) ];
    }

    return undef;
}

# Check the array component number in the RAID array device
sub _checkArrayCompNum # (arrayName, arrayInfo, storedInfo)
{

    my ($self, $arrayName, $arrayInfo, $storedInfo) = @_;

    if ( $storedInfo->{deviceNumber} != $arrayInfo->{activeDevices} ) {
        my $evtMsg = __x('RAID device {name} has changed its number '
                         . 'of active components from {oldNum} to {newNum}',
                         name => $arrayName,
                         oldNum => $storedInfo->{deviceNumber},
                         newNum => $arrayInfo->{activeDevices});

        return [ new EBox::Event(level   => 'info',
                                 source  => $self->name(),
                                 message => $evtMsg) ];
    }

    return undef;

}

# Check the array component number in the RAID array device
sub _checkArrayCompNum # (arrayName, arrayInfo, storedInfo)
{

    my ($self, $arrayName, $arrayInfo, $storedInfo) = @_;

    if ( $storedInfo->{deviceNumber} != $arrayInfo->{activeDevices} ) {
        my $evtMsg = __x('RAID device {name} has changed its number '
                         . 'of active components from {oldNum} to {newNum}',
                         name => $arrayName,
                         oldNum => $storedInfo->{deviceNumber},
                         newNum => $arrayInfo->{activeDevices});

        return [ new EBox::Event(level   => 'info',
                                 source  => $self->name(),
                                 message => $evtMsg) ];
    }

    return undef;

}

# Check the current operation in the RAID array device
sub _checkArrayOp # (arrayName, arrayInfo, storedInfo)
{

    my ($self, $arrayName, $arrayInfo, $storedInfo) = @_;

    my ($evtMsg, $showPer) = ('', 0);
    if ( $storedInfo->{operation} ne $arrayInfo->{operation} ) {
        if ( $storedInfo->{operation} eq 'none' ) {
             $evtMsg = __x('RAID device {name} has started operation {opName}',
                           name   => $arrayName,
                           opName => $self->_i18nOp($arrayInfo->{operation}),
                          ) . '\n';
             $showPer = 1;
         } elsif ( $arrayInfo->{operation} eq 'none' ) {
             $evtMsg = __x('RAID device {name} has finished operation {opName} '
                           . 'or it was aborted',
                           name   => $arrayName,
                           opName => $self->_i18nOp($storedInfo->{operation}));
         } else {
             # None is 'none' operation
             $evtMsg = __x('RAID device {name} has finished operation {oldOpName} '
                           . 'and started {newOpName}',
                           name      => $arrayName,
                           oldOpName => $self->_i18nOp($storedInfo->{operation}),
                           newOpName => $self->_i18nOp($arrayInfo->{operation})
                          ) . '\n';
             $showPer = 1;
         }
    } elsif ( $arrayInfo->{operation} ne 'none' ) {
        # An operation in RAID array is being performed, show percentage
        $evtMsg = __x('RAID device {name} is performing operation {opName}',
                      name   => $arrayName,
                      opName => $self->_i18nOp($arrayInfo->{operation})
                     ) . '\n';
        $showPer = 1;
    }

    if ( $evtMsg ) {
        if ( $showPer ) {
            $evtMsg .= __x('Status: {percentage}% completed',
                           percentage => $arrayInfo->{operationPercentage}) . '\n';
            $evtMsg .= __x('Estimated finish time: {time}',
                           time => $arrayInfo->{operationEstimatedTime});
        }
        return [ new EBox::Event(level   => 'info',
                                 source  => $self->name(),
                                 message => $evtMsg) ];
    } else {
        return undef;
    }

}

# Check each array component in the RAID array device
sub _checkComponents # (arrayName, arrayInfo, storedInfo)
{

    my ($self, $arrayName, $arrayInfo, $storedInfo) = @_;

    my %currentComps = map { $_->{device} => $_->{state} } values %{$arrayInfo->{raidDevices}};
    my %storedComps  = map { $_->{device} => $_->{state} } @{$storedInfo->{components}};

    my @compEvents = ();
    my $evtMsg;
    foreach my $currentComp (keys %currentComps) {
        if ( exists $storedComps{$currentComp} ) {
            # Check updates
            my $oldStatus = $storedComps{$currentComp};
            my $newStatus = $currentComps{$currentComp};
            if ( $newStatus ne $oldStatus ) {
                if ( $newStatus eq 'failure'
                     and $oldStatus eq 'up') {
                    $evtMsg = __x('Active component {compName} from RAID array {arrayName} '
                                  . 'has been marked as faulty',
                                  compName  => $currentComp,
                                  arrayName => $arrayName);
                    push ( @compEvents, new EBox::Event(level   => 'error',
                                                        source  => $self->name(),
                                                        message => $evtMsg));
                } elsif ( $newStatus eq 'failure'
                          and $oldStatus eq 'spare' ) {
                    $evtMsg = __x('Spare component {compName} from RAID array {arrayName} '
                                  . 'which was being rebuilt to replace a faulty device '
                                  . 'has failed',
                                  compName  => $currentComp,
                                  arrayName => $arrayName);
                    push ( @compEvents, new EBox::Event(level   => 'error',
                                                        source  => $self->name(),
                                                        message => $evtMsg));
                } elsif ( $newStatus eq 'up'
                          and $oldStatus eq 'spare' ) {
                    $evtMsg = __x('Spare component {compName} from RAID array {arrayName} '
                                  . 'which was being rebuilt to replace a faulty device '
                                  . 'has been successfully rebuilt and has been made '
                                  . 'active',
                                  compName  => $currentComp,
                                  arrayName => $arrayName);
                    push ( @compEvents, new EBox::Event(level   => 'info',
                                                        source  => $self->name(),
                                                        message => $evtMsg));
                }
            }
        } else {
            # An addition
            $evtMsg = __x('A new component {compName} has been hot added '
                          . 'to RAID device {arrayName} with status {status}',
                          compName  => $currentComp,
                          arrayName => $arrayName,
                          status    => $self->_i18nCompStatus($currentComps{$currentComp}));
            push ( @compEvents, new EBox::Event(level   => 'info',
                                                source  => $self->name(),
                                                message => $evtMsg));
        }
    }
    # Check removals
    foreach my $storedComp (keys %storedComps) {
        next if (exists $currentComps{$storedComp});
        $evtMsg = __x('A component {compName} has been hot removed from '
                      . 'RAID array {arrayName} when its status was {status}',
                     compName  => $storedComp,
                     arrayName => $arrayName,
                     status    => $storedComps{$storedComp});
        push ( @compEvents, new EBox::Event(level   => 'warn',
                                            source  => $self->name(),
                                            message => $evtMsg));
    }

    return \@compEvents;

}


# Group: Helper methods

# Get the array i18ned state message
sub _i18nState
{
    my ($self, $state) = @_;

    my @singleStates = split( ', ', $state);
    my @i18nedStates = ();
    foreach my $singleState (@singleStates) {
        if ( $singleState eq 'active' ) {
            push(@i18nedStates, __('active'));
        } elsif ( $singleState eq 'degraded' ) {
            push(@i18nedStates, __('degraded'));
        } elsif ( $singleState eq 'recovering' ) {
            push(@i18nedStates, __('recovering'));
        } elsif ( $singleState eq 'resyncing' ) {
            push(@i18nedStates, __('resyncing'));
        } elsif ( $singleState eq 'rebuilding' ) {
            push(@i18nedStates, __('rebuilding'));
        } elsif ( $singleState eq 'reshaping' ) {
            push(@i18nedStates, __('reshaping'));
        } elsif ( $singleState eq 'failed' ) {
            push(@i18nedStates, __('failed'));
        }
    }
    return join( ', ', @i18nedStates);

}

sub _i18nOp
{
    my ($self, $op) = @_;

    if ( $op eq 'resync' ) {
        return __('resync');
    } elsif ( $op eq 'rebuild' ) {
        return __('rebuild');
    } elsif ( $op eq 'reshape' ) {
        return __('reshape');
    } elsif ( $op eq 'recovery' ) {
        return __('recovery');
    }
    return '';
}

# Get the component i18ned status message
sub _i18nCompStatus
{
    my ($self, $status) = @_;

    if ( $status eq 'up' ) {
        return __('active');
    } elsif ( $status eq 'failure' ) {
        return __('faulty');
    } elsif ( $status eq 'spare' ) {
        return __('spare');
    }

}

1;
