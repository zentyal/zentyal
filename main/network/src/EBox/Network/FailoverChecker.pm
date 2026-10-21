# Copyright (C) 2026 Zentyal S.L.
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

# Class: EBox::Network::FailoverChecker
#
#   WAN failover check: tests the gateways with failover rules, disables the
#   failing ones, enables back the recovered ones and regenerates the
#   multi-WAN routing when needed. It is run from cron and from the network
#   link monitor through the failover-checker script.
#
package EBox::Network::FailoverChecker;

use strict;
use warnings;

use EBox;
use EBox::Network;
use EBox::NetWrappers;
use EBox::Global;
use EBox::Sudo;
use EBox::Util::Lock;
use EBox::Validate;
use EBox::Exceptions::Lock;

use TryCatch;
use Socket qw(inet_ntoa);
use Fcntl qw(:flock);

use constant PING_PATTERN => '7a6661696c6f76657274657374';
use constant PING_PATTERN_TEXT => 'zfailovertest';

# Method: new
#
#   Creates a new WAN failover checker
#
sub new
{
    my ($class) = @_;

    my $self = {};
    bless($self, $class);

    return $self;
}

# Method: _networkLocked
#
#   Returns whether the network module lock is held by another process,
#   without acquiring it and without logging anything. The lock file is the
#   one used by EBox::Module::Base::_lock() and Network::regenGateways(), so
#   this tells us whether the network module is being configured.
#
#   Implemented here (instead of adding a public helper to EBox::Util::Lock)
#   so the network package keeps working with the core version it depends on,
#   without requiring a newer one.
#
sub _networkLocked
{
    my ($self) = @_;

    my $file = EBox::Util::Lock::_lockFile('network');
    open(my $fh, '<', $file) or return 0;

    my $locked = not flock($fh, LOCK_EX | LOCK_NB);
    close($fh);

    return $locked;
}

# Method: run
#
#   Runs the whole WAN failover check
#
sub run
{
    my ($self) = @_;

    my $network = EBox::Global->getInstance(1)->modInstance('network');
    $self->{network} = $network;

    EBox::debug('Starting failover check...');

    # The network module regenerates the routing itself while it is being
    # configured (a save, a restart or its boot setup holds its lock): skip
    # the check in that case, the tests would see the routing mid-application
    # and disable gateways that are actually fine.
    if ($self->_networkLocked()) {
        EBox::debug('The network module is being configured: skipping the failover check');
        return;
    }

    # Getting readonly instance to test the gateways
    $self->{global} = EBox::Global->getInstance(1);
    $network = $self->{global}->modInstance('network');
    $self->{network} = $network;

    $self->{rules} = $network->model('WANFailoverRules');
    $self->{gateways} = $network->model('GatewayTable');
    $self->{marks} = $network->marksForRouters();
    $self->{failed} = {};
    $self->{needRegen} = 0;

    foreach my $id (@{$self->{rules}->enabledRows()}) {
        EBox::debug("Testing rules for gateway with id $id...");
        $self->_testRule($self->{rules}->row($id));
    }

    # We won't do anything if there are unsaved changes
    my $readonly = EBox::Global->getInstance()->modIsChanged('network');
    $self->{readonly} = $readonly;

    unless ($readonly) {
        # Getting read/write instance to apply the changes
        $self->{network} = EBox::Global->modInstance('network');
        $self->{gateways} = $self->{network}->model('GatewayTable');
    }

    EBox::debug('Applying changes in the gateways table...');

    my $needSave = 0;
    # Older versions did not keep track of the gateways they disabled, so the
    # first time this checker runs the disabled gateways are assumed to be
    # disabled by the failover (see EBox::Network::failoverDisabledInitialized)
    my $flagsInitialized = $self->{network}->failoverDisabledInitialized();
    foreach my $id (@{$self->{gateways}->ids()}) {
        my $row = $self->{gateways}->row($id);
        my $gwName = $row->valueByName('name');
        my $enabled = $row->valueByName('enabled');

        my $enable = gatewayEnablement(
            $enabled, $self->{failed}->{$id},
            $self->{network}->failoverDisabledGateway($id), $flagsInitialized);

        EBox::debug("Properties for gateway $gwName ($id): enabled=$enabled, enable=$enable");

        # We don't do anything if the previous state is the same
        if ($enable xor $enabled) {
            unless ($readonly) {
                $row->elementByName('enabled')->setValue($enable);
                $row->store();
                $self->{network}->setFailoverDisabledGateway($id, not $enable);
                $needSave = 1;
                if ($enable) {
                    EBox::info("Gateway $gwName connected again.");
                }
            }
        }
    }

    unless ($readonly) {
        # From now on the disabled state of every gateway is tracked
        $self->{network}->setFailoverDisabledInitialized();
    }

    if ($readonly) {
        EBox::warn('The WAN failover check did nothing because there are unsaved changes in the Zentyal interface: save or discard them to resume it.');
    }

    my ($setAsDefault, $unsetAsDefault);
    # Check if default gateway has been disabled and choose another
    my $default = $self->{gateways}->findValue('default' => 1);
    my $originalId = $self->{network}->selectedDefaultGateway();
    EBox::debug("The preferred default gateway is $originalId");
    unless ($default and $default->valueByName('enabled')) {
        # If the original default gateway is alive, restore it
        my $original;
        $original = $self->{gateways}->row($originalId) if $originalId;
        if ($original and $original->valueByName('enabled')) {
            $original = $self->{gateways}->row($originalId);
            $unsetAsDefault = $default;
            $setAsDefault   = $original;
            EBox::debug('The original default gateway will be restored');
            $needSave = 1;
        } else {
            EBox::debug('Checking if there is another enabled gateway to set as default');
            # Check if we can find another enabled to set it as default
            my $other = $self->{gateways}->findValue('enabled' => 1);
            if ($other) {
                $unsetAsDefault = $default;
                $setAsDefault   = $other;
            }
        }
    } else {
        # check if the gw enabled is the prefered one
        if ($originalId and ($default->id() ne $originalId)) {
            my $original = $self->{gateways}->row($originalId);
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

    if ($needSave or ($self->{needRegen} and not $readonly)) {
        EBox::debug('Regenerating rules for the gateways');
        $self->{network}->regenGateways();

        foreach my $module (@{$self->{global}->modInstancesOfType('EBox::NetworkObserver')}) {
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

    EBox::debug('Failover check finished...');
}

# Method: gatewayEnablement
#
#   Returns the enabled value a gateway must have after a failover check: it
#   is disabled when its tests fail and enabled back when they pass again, but
#   only if the failover disabled it itself. The disabled gateways are enabled
#   back while the failover disabled flags are not initialized yet, as older
#   versions did not track the gateways they disabled.
#
# Parameters:
#
#   enabled - current enabled value of the gateway
#   failed - whether the tests of the gateway failed (undef when it is not
#            tested by any failover rule)
#   failoverDisabled - whether the gateway was disabled by the failover
#   flagsInitialized - whether the failover disabled flags are initialized
#
# Returns:
#
#   the enabled value the gateway must have
#
sub gatewayEnablement
{
    my ($enabled, $failed, $failoverDisabled, $flagsInitialized) = @_;

    return $enabled unless defined($failed);

    return 0 if ($failed);
    return 1 if ($failoverDisabled or (not $flagsInitialized));

    return $enabled;
}

# Method: testFailure
#
#   Returns whether the given probe results make the failover test fail
#
# Parameters:
#
#   fails - number of failed probes
#   usedProbes - number of probes run
#   ratio - required success ratio (0..1)
#
sub testFailure
{
    my ($fails, $usedProbes, $ratio) = @_;

    my $failRatio = ($usedProbes ? ($fails / $usedProbes) : 1);
    return ($failRatio >= (1 - $ratio));
}

# Method: routeProblem
#
#   Returns the reason why the marked probes of a gateway would not leave
#   through the given interface (or undef when they would) and whether the
#   policy routing must be regenerated. The probes are marked to leave through
#   the gateway's own policy table: if the interface is down or its policy
#   route is missing they fall through to another WAN and the ping would
#   wrongly succeed.
#
# Parameters:
#
#   iface - real interface name the probes must leave through
#   up - whether the interface is up
#   table - policy table of the gateway
#   tableRoutes - array ref with the routes of the policy table
#   routeOutput - output of the route lookup for the marked probes
#
# Returns:
#
#   a list with the problem description (undef when there is none) and
#   whether the problem is a missing policy route
#
sub routeProblem
{
    my ($iface, $up, $table, $tableRoutes, $routeOutput) = @_;

    return ("interface $iface is down", 0) unless $up;

    unless (grep { /^\s*default\b/ } @{$tableRoutes}) {
        return ("there is no policy route for the gateway in table $table", 1);
    }

    unless ($routeOutput =~ /\bdev\s+(\S+)/) {
        return ("there is no route for the marked probes through $iface", 1);
    }
    if ($1 ne $iface) {
        return ("the marked probes would leave through $1 instead of $iface", 1);
    }

    return (undef, 0);
}

# Method: _testRule
#
#   Tests the gateway of the given failover rule, marking it as failed when
#   needed
#
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
            EBox::debug("PPP interface down, mark test as failed");
            $self->{failed}->{$gw} = 1;
            return;
        }
    }

    my $address = $network->ifaceAddress($iface);
    if (not $address) {
        EBox::debug("$iface has not address. Failing test.");
        $self->{failed}->{$gw} = 1;
        return;
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

    # Do not trust the ping if the marked probes would leave through another WAN
    my ($routeProblem, $routeMissing) =
        $self->_probeRouteProblem($network->realIface($iface),
                                  $address, $self->{marks}->{$gw}, $host);
    if ($routeProblem) {
        if ($routeMissing) {
            # The probes cannot be trusted because the multi-WAN routing is
            # stale or missing (e.g. NetworkManager re-added the DHCP default
            # route to the main table): regenerate it and keep the gateway
            # state untouched instead of disabling a gateway that may be
            # fine. A gateway that is already disabled stays disabled until
            # its probes can be trusted again.
            EBox::debug("Cannot test gateway $gwName: $routeProblem. Regenerating the routing.");
            $self->{failed}->{$gw} = 1 unless $wasEnabled;
            $self->{needRegen} = 1;
        } else {
            EBox::debug("Cannot test gateway $gwName: $routeProblem. Failing test.");
            $self->_markAsFailed($gw, $gwName, $wasEnabled, $routeProblem);
        }
        return;
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
    try {
        $self->_setIptablesRule($gw, 1, $type, $host);
    } catch ($e) {
        # The routing may be mid-regeneration (the chains are recreated by
        # EBox::Network::_multigwRoutes): do not trust this run for this
        # gateway, the next check tests it again
        EBox::warn("Cannot set the failover test rule for $gwName: $e");
        return;
    }

    for (1..$probes) {
        $usedProbes++;
        if ($self->_runTest($type, $host, $address)) {
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

    if (testFailure($fails, $usedProbes, $ratio)) {
        my $failRatio = ($usedProbes ? ($fails / $usedProbes) : 1);
        my $printableRatio = sprintf("%.2f", $failRatio*100);
        my $maxRatio = $maxFailRatio * 100;
        my $reason = "'$typeName' test to host '$host' has failed ${printableRatio}%, max=${maxRatio}%.";
        $self->_markAsFailed($gw, $gwName, $wasEnabled, $reason);
    }
}

# Method: _markAsFailed
#
#   Marks a gateway as failed and logs an event when it was previously enabled
#
# Parameters:
#
#   gw - gateway id
#   gwName - gateway name
#   wasEnabled - whether the gateway was enabled before the test
#   reason - string describing why the gateway is considered disconnected
#
sub _markAsFailed
{
    my ($self, $gw, $gwName, $wasEnabled, $reason) = @_;

    $self->{failed}->{$gw} = 1;

    # Only generate event if gateway was not already disabled
    return unless ($wasEnabled);

    EBox::info("Gateway $gwName disconnected: $reason");
}

# Method: _probeRouteProblem
#
#   Returns the reason why the marked probes would not leave through the given
#   interface (undef if they would) and whether the policy routing must be
#   regenerated. The probes are marked to leave through the gateway's own
#   policy table; if its route is missing they fall through to another WAN and
#   the ping would wrongly succeed.
#
# Parameters:
#
#   iface - real interface name the probes must leave through
#   address - source address used by the probes
#   mark - fwmark assigned to the gateway
#   host - probe destination (an IP address or a host name)
#
sub _probeRouteProblem
{
    my ($self, $iface, $address, $mark, $host) = @_;

    my $up = 0;
    try {
        $up = EBox::NetWrappers::iface_is_up($iface);
    } catch {
        $up = 0;
    }
    return routeProblem($iface, 0, 0, [], '') unless $up;

    my $table = 100 + $mark;
    my $tableRoutes = EBox::Sudo::rootWithoutException(
        "/sbin/ip route show table $table 2>/dev/null || true");

    my $dst = $host;
    unless (EBox::Validate::checkIP($dst)) {
        # The host field is an IP address, but rules created by older
        # versions may hold a host name: resolve it to check its route
        my @resolved = gethostbyname($host);
        return (undef, 0) unless @resolved;
        $dst = inet_ntoa($resolved[4]);
    }

    my $output = EBox::Sudo::rootWithoutException(
        "/sbin/ip route get $dst from $address mark $mark 2>/dev/null || true");

    return routeProblem($iface, $up, $table, $tableRoutes, join(' ', @{$output}));
}

# Method: _runTest
#
#   Runs a single probe of the given test type
#
sub _runTest
{
    my ($self, $type, $host, $localAddress) = @_;

    my $result;
    if (($type eq 'gw_ping') or ($type eq 'host_ping')) {
        $result = system("ping -W5 -c1 -I $localAddress -p" . PING_PATTERN . " $host");
    } elsif ($type eq 'http') {
        my $command = "wget $host --bind-address=$localAddress --tries=1 -T 5 -O /dev/null";
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

# Method: _setIptablesRule
#
#   Adds (or removes) the mangle rule marking the packets of the probes so
#   they leave through the gateway being tested
#
sub _setIptablesRule
{
    my ($self, $gw, $set, $type, $dst) = @_;

    my $chain = EBox::Network::FAILOVER_CHAIN();
    # Create the chain if it does not exist yet (it is created by
    # EBox::Network::_multigwRoutes) and flush its previous rules; both fail
    # silently
    EBox::Sudo::silentRoot("/sbin/iptables -t mangle -N $chain");
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

1;
