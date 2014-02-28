# Copyright (C) 2009-2013 Zentyal S.L.
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

# Class: EBox::Event::Watcher::Gateways;
#
# This class is a watcher which checks connection/disconnection of gateways
#
package EBox::Event::Watcher::Gateways;

use base 'EBox::Event::Watcher::Base';

use EBox::Network;
use EBox::Event;
use EBox::Global;
use EBox::Gettext;
use EBox::Validate;
use EBox::Exceptions::Lock;

use TryCatch::Lite;

use constant PING_PATTERN => '7a6661696c6f76657274657374';
use constant PING_PATTERN_TEXT => 'zfailovertest';

# Group: Public methods

# Constructor: new
#
#        The constructor for <EBox::Event::Watcher::Gateways>
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
#        <EBox::Event::Watcher::Gateways> - the newly created object
#
sub new
{
    my ($class) = @_;

    my $network = EBox::Global->getInstance(1)->modInstance('network');
    my $options = $network->model('WANFailoverOptions')->row();
    my $period = $options->valueByName('period');

    my $self = $class->SUPER::new(period => $period);
    $self->{counter} = 0;

    bless ($self, $class);

    return $self;
}

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

# Method: run
#
#        Check state of the gateways.
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::run>
#
# Returns:
#
#        array ref - <EBox::Event> an info event is sent if Zentyal is up and
#        running and a fatal event if Zentyal is down
#
sub run
{
    my ($self) = @_;

    EBox::debug('Entering failover event...');

    $self->{eventList} = [];
    $self->{failed} = {};

    # Getting readonly instance to test the gateways
    my $global = EBox::Global->getInstance(1);
    my $network = $global->modInstance('network');

    return [] unless $network->isEnabled();

    my $rules = $network->model('WANFailoverRules');
    my $gateways = $network->model('GatewayTable');
    $self->{gateways} = $gateways;
    $self->{marks} = $network->marksForRouters();

    my @enabledRules = @{$rules->enabledRows()};

    # If we don't have any enabled rule we finish here
    return [] unless @enabledRules;

    foreach my $id (@enabledRules) {
        EBox::debug("Testing rules for gateway with id $id...");
        my $row = $rules->row($id);
        $self->_testRule($row);
    }

    # We won't do anything if there are unsaved changes
    my $readonly = EBox::Global->getInstance()->modIsChanged('network');

    unless ($readonly) {
        # Getting read/write instance to apply the changes
        $network = EBox::Global->modInstance('network');
        $gateways = $network->model('GatewayTable');
    }

    EBox::debug('Applying changes in the gateways table...');

    my $needSave = 0;
    foreach my $id (@{$gateways->ids()}) {
        my $row = $gateways->row($id);
        my $gwName = $row->valueByName('name');
        my $enabled = $row->valueByName('enabled');

        # It must be enabled if all tests are passed
        my $enable = $enabled;
        if (defined($self->{failed}->{$id})) {
            $enable = not($self->{failed}->{$id})
        };

        EBox::debug("Properties for gateway $gwName ($id): enabled=$enabled, enable=$enable");

        # We don't do anything if the previous state is the same
        if ($enable xor $enabled) {
            unless ($readonly) {
                $row->elementByName('enabled')->setValue($enable);
                $row->store();
                $needSave = 1;
            }
            if ($enable) {
                my $event = new EBox::Event(message    => __x("Gateway {gw} connected again.", gw => $gwName),
                                            level      => 'info',
                                            source     => 'WAN Failover',
                                            additional => { 'up' => 1, gateway => $gwName });
                push (@{$self->{eventList}}, $event);
            }
        }
    }

    if ($readonly) {
        EBox::warn('Leaving failover event without doing anything due to unsaved changes on the Zentyal interface.');
        foreach my $event (@{$self->{eventList}}) {
            $event->{message} = __('WARNING: These changes are not applied due to unsaved changes on the administration interface.') . "\n\n" . $event->{message};
        }
        return $self->{eventList};
    }

    my ($setAsDefault, $unsetAsDefault);
    # Check if default gateway has been disabled and choose another
    my $default = $gateways->findValue('default' => 1);
    my $originalId = $network->selectedDefaultGateway();
    EBox::debug("The preferred default gateway is $originalId");
    unless ($default and $default->valueByName('enabled')) {
        # If the original default gateway is alive, restore it
        my $original;
        $original = $gateways->row($originalId) if $originalId;
        if ($original and $original->valueByName('enabled')) {
            $original = $gateways->row($originalId);
            $unsetAsDefault = $default;
            $setAsDefault   = $original;
            EBox::debug('The original default gateway will be restored');
            $needSave = 1;
        } else {
            EBox::debug('Checking if there is another enabled gateway to set as default');
            # Check if we can find another enabled to set it as default
            my $other = $gateways->findValue('enabled' => 1);
            if ($other) {
                $unsetAsDefault = $default;
                $setAsDefault   = $other;
            }
        }
    } else {
        # check if the gw enabled is the prefered one
        if ($originalId and ($default->id() ne $originalId)) {
            my $original = $gateways->row($originalId);
            if ($original and $original->valueByName('enabled')) {
                EBox::debug('The original default gateway will replace the current default');
                $unsetAsDefault = $default;
                $setAsDefault   = $original;
            }
        }
    }

    if ($unsetAsDefault) {
        $unsetAsDefault->elementByName('default')->setValue(0);
        $unsetAsDefault->store();
        EBox::debug("The gateway " .  $unsetAsDefault->valueByName('name').
                        " is not longer default");
        $needSave = 1;
    }

    if ($setAsDefault) {
        $setAsDefault->elementByName('default')->setValue(1);
        $setAsDefault->store();
        EBox::debug("The gateway " .  $setAsDefault->valueByName('name').
                        " is now the default");
        $needSave = 1;
    }

    if ($needSave) {
        EBox::debug('Regenerating rules for the gateways');
        $network->regenGateways();

        foreach my $module (@{$global->modInstancesOfType('EBox::NetworkObserver')}) {
            my $timeout = 60;
            while ($timeout) {
                my $done = 0;
                try {
                    $module->regenGatewaysFailover();
                    $done = 1;
                } catch (EBox::Exceptions::Lock $e) {
                    sleep 5;
                    $timeout -= 5;
                }
                if ($done) {
                    last;
                }
            }
            if ($timeout <= 0) {
                EBox::error("WAN Failover: $module->{name} module has been locked for 60 seconds.");
            }
        }
    } else {
        EBox::debug('No need to regenerate the rules for the gateways');
    }

    EBox::debug('Leaving failover event...');

    return $self->{eventList};
}

sub _testRule
{
    my ($self, $row) = @_;

    my $gw = $row->valueByName('gateway');
    my $network = EBox::Global->modInstance('network');

    my $gwName = $self->{gateways}->row($gw)->valueByName('name');
    my $iface = $self->{gateways}->row($gw)->valueByName('interface');
    my $wasEnabled = $self->{gateways}->row($gw)->valueByName('enabled');

    EBox::debug("Entering _testRule for gateway $gwName...");

    # First test on this gateway, initialize its entry on the hash
    unless (exists $self->{failed}->{$gw}) {
        $self->{failed}->{$gw} = 0;
    }

    # If a test for this gw has already failed we don't test any other
    return if ($self->{failed}->{$gw});

    my ($ppp_iface, $iface_up);
    if ($network->ifaceMethod($iface) eq 'ppp') {
        EBox::debug("It is a PPPoE gateway");

        $ppp_iface = $network->realIface($iface);
        $iface_up = !($ppp_iface eq $iface);

        EBox::debug("Iface $ppp_iface up? = $iface_up");

        if (!$iface_up) {
            # PPP interface down, do not make test (not needed)
            $self->{failed}->{$gw} = 1;
            return;
        }
    }

    my $type = $row->valueByName('type');
    my $typeName = $row->printableValueByName('type');
    my $host = $row->valueByName('host');

    EBox::debug("Running $typeName tests for gateway $gwName...");

    if ($type eq 'gw_ping') {
        my $gwRow = $self->{gateways}->row($gw);
        $host = $gwRow->valueByName('ip');
        return unless $host;
    }

    my $probes = $row->valueByName('probes');
    my $ratio = $row->valueByName('ratio') / 100;
    my $neededSuccesses = $probes * $ratio;
    my $maxFailRatio = 1 - $ratio;
    my $maxFails = $probes * $maxFailRatio;

    my $usedProbes = 0;
    my $successes  = 0;
    my $fails      = 0;

    # Set rule for outgoing traffic through the gateway we are testing
    $self->_setIptablesRule($gw, 1, $type, $host);

    for (1..$probes) {
        $usedProbes++;
        if ($self->_runTest($type, $host)) {
            EBox::debug("Probe number $_ succeded.");
            $successes++;
            last if ($successes >= $neededSuccesses);
        } else {
            EBox::debug("Probe number $_ failed.");
            $fails++;
            last if ($fails >= $maxFails);
        }
    }

    # Clean rule
    $self->_setIptablesRule($gw, 0);

    my $failRatio = $fails / $usedProbes;
    if ($failRatio >= $maxFailRatio) {
        $self->{failed}->{$gw} = 1;

        # Only generate event if gateway was not already disabled
        return unless ($wasEnabled);

        my $disconnectMsg = __x('Gateway {gw} disconnected', gw => $gwName);
        my $reason =__x("'{type}' test to host '{host}' has failed {failRatio}%, max={maxFailRatio}%.",
                        failRatio => sprintf("%.2f", $failRatio*100),
                        type => $typeName, host => $host, maxFailRatio => $maxFailRatio*100);
        my $explanation = __('This gateway will be connected again if the test are passed.');
        my $event = new EBox::Event(message => "$disconnectMsg\n\n$reason\n$explanation",
                                    level   => 'error',
                                    source  => 'WAN Failover',
                                    additional => { down => 1,
                                                    gateway => $gwName,
                                                    type => $type,
                                                    host => $host,
                                                    fail_ratio => $failRatio,
                                                    max_fail_ratio => $maxFailRatio,
                                                }
                                   );
        push (@{$self->{eventList}}, $event);
    }
}

sub _runTest
{
    my ($self, $type, $host) = @_;

    my $result;

    if (($type eq 'gw_ping') or ($type eq 'host_ping')) {
        $result = system("ping -W5 -c1 -p" . PING_PATTERN . " $host");
    } elsif ($type eq 'http') {
        my $command = "wget $host --tries=1 -T 5 -O /dev/null";
        $result = system($command);
    } elsif ($type eq 'dns') {
        # DEPRECATED test type, we mantain here just for backwards compability
        $result = system("host -W 5 $host");
    } else {
        EBox::error("Invalid type of failover test: $type");
        return 0;
    }

    return $result == 0;
}

sub _setIptablesRule
{
    my ($self, $gw, $set, $type, $dst) = @_;

    my $chain = EBox::Network::FAILOVER_CHAIN();
    # Flush previous rules from custom chain. It'll fail silently
    # if it doesn't exist
    EBox::Sudo::silentRoot("/sbin/iptables -t mangle -F $chain");

    if ($set) {
        # Add rule to mark packets generated by zentyal, i.e: failover tests
        my $rule =  "/sbin/iptables -t mangle -A $chain ";
        if (($type eq 'gw_ping') or ($type eq 'host_ping')) {
            $rule .= '--proto icmp --icmp-type echo-request ';
            $rule .= '-m string --algo bm  --string ' . PING_PATTERN_TEXT . ' ';
        } elsif ($type eq 'dns') {
            $rule .= '--proto udp --dport 53 ';
        } elsif ($type eq 'http') {
            $rule .= '--proto tcp --dport 80 ';
        }
        $rule .= "--dst $dst ";

        my $mark = $self->{marks}->{$gw};
        $rule .= "-j MARK --set-mark $mark";
        EBox::Sudo::root($rule);
    }
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
    return __('WAN Failover');
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
    return __('Check if gateways are connected or disconnected.');
}

1;
