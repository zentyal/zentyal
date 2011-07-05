# Copyright (C) 2009-2011 eBox Technologies S.L.
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

package EBox::Event::Watcher::Gateways;

# Class: EBox::Event::Watcher::Gateways;
#
# This class is a watcher which checks connection/disconnection of gateways
#
use base 'EBox::Event::Watcher::Base';

use EBox::Event;
use EBox::Global;
use EBox::Gettext;
use EBox::Validate;
use EBox::Exceptions::Lock;

use Error qw(:try);

# TODO: Remove this once we change the debug behavior
# to log only if debug = yes
my $debug = EBox::Config::configkey('debug') eq 'yes';

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

    my $network = EBox::Global->modInstance('network');
    my $options = $network->model('WANFailoverOptions')->row();
    my $period = $options->valueByName('period');

    my $self = $class->SUPER::new(
                                    period => $period,
                                    domain => 'ebox-network',
                                 );
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

    logIfDebug('Entering failover event...');

    $self->{eventList} = [];
    $self->{failed} = {};

    my $global = EBox::Global->getInstance();
    my $network = $global->modInstance('network');

    return [] unless $network->isEnabled();

    # We don't do anything if there are unsaved changes
    if ($global->modIsChanged('network')) {
        EBox::warn('Failover event disabled due to unsaved changes on the Zentyal interface.');
        return [];
    }

    my $rules = $network->model('WANFailoverRules');
    my $gateways = $network->model('GatewayTable');
    $self->{gateways} = $gateways;
    $self->{marks} = $network->marksForRouters();

    my @enabledRules = @{$rules->enabledRows()};

    # If we don't have any enabled rule we finish here
    return [] unless @enabledRules;

    foreach my $id (@enabledRules) {
        logIfDebug("Testing rules for gateway with id $id...");
        my $row = $rules->row($id);
        $self->_testRule($row);
    }

    # We don't do anything if there are unsaved changes
    return [] if $global->modIsChanged('network');
    if ($global->modIsChanged('network')) {
        EBox::warn('Leaving failover event without doing anything due to unsaved changes on the Zentyal interface.');
        return [];
    }

    logIfDebug('Applying changes in the gateways table...');

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

        logIfDebug("Properties for gateway $gwName ($id): enabled=$enabled, enable=$enable");

        # We don't do anything if the previous state is the same
        if ($enable xor $enabled) {
            $row->elementByName('enabled')->setValue($enable);
            $row->store();
            $needSave = 1;
            if ($enable) {
                my $event = new EBox::Event(message => __x("Gateway {gw} connected again.", gw => $gwName),
                                    level   => 'warn',
                                    source  => 'WAN Failover');
                push (@{$self->{eventList}}, $event);
            }
        }
    }

    # Check if default gateway has been disabled and choose another
    my $default = $gateways->findValue('default' => 1);

    unless ($default and $default->valueByName('enabled')) {
        # If the original default gateway is alive, restore it
        my $originalId = $network->selectedDefaultGateway();
        logIfDebug("The preferred default gateway is $originalId");
        my $original = $gateways->row($originalId);
        if ($original and $original->valueByName('enabled')) {
            if ( $default ) {
                $default->elementByName('default')->setValue(0);
                $default->store();
            }
            $original->elementByName('default')->setValue(1);
            $original->store();
            logIfDebug('The original default gateway has been restored');
            $needSave = 1;
        } else {
            logIfDebug('Checking if there is another enabled gateway to set as default');
            # Check if we can find another enabled to set it as default
            my $other = $gateways->findValue('enabled' => 1);
            if ($other) {
                if ( $default ) {
                    $default->elementByName('default')->setValue(0);
                    $default->store();
                }
                $other->elementByName('default')->setValue(1);
                $other->store();
                my $otherName = $other->valueByName('name');
                logIfDebug("The gateway $otherName is now the default");
                $needSave = 1;
            }
        }
    }

    if ($needSave) {
        logIfDebug('Regenerating rules for the gateways');
        $network->regenGateways();

        # Workaround for squid problem
        if ($global->modExists('squid')) {
            my $squid = $global->modInstance('squid');
            my $timeout = 60;
            while ($timeout) {
                try {
                    $squid->restartService();
                    last;
                } catch EBox::Exceptions::Lock with {
                    sleep 5;
                    $timeout -= 5;
                };
            }
            if ($timeout <= 0) {
                EBox::error('WAN Failover: proxy module has been locked for 60 seconds.');
            }
        }
    } else {
        logIfDebug('No need to regenerate the rules for the gateways');
    }

    logIfDebug('Leaving failover event...');

    return $self->{eventList};
}

sub _testRule # (row)
{
    my ($self, $row) = @_;

    my $gw = $row->valueByName('gateway');

    my $gwName = $self->{gateways}->row($gw)->valueByName('name');

    logIfDebug("Entering _testRule for gateway $gwName...");

    # First test on this gateway, initialize its entry on the hash
    unless (exists $self->{failed}->{$gw}) {
        $self->{failed}->{$gw} = 0;
    }

    # If a test for this gw has already failed we don't test any other
    return if ($self->{failed}->{$gw});

    logIfDebug("Running $typeName tests for gateway $gwName...");

    my $type = $row->valueByName('type');
    my $typeName = $row->printableValueByName('type');
    my $host = $row->valueByName('host');

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

    my $successes = 0;
    my $fails = 0;

    # Set rule for outgoing traffic through the gateway we are testing
    $self->_setIptablesRule($gw, 1);

    for (1..$probes) {
        if ($self->_runTest($type, $host)) {
            logIfDebug("Probe number $_ succeded.");
            $successes++;
            last if ($successes >= $neededSuccesses);
        } else {
            logIfDebug("Probe number $_ failed.");
            $fails++;
            last if ($fails >= $maxFails);
        }
    }

    # Clean rule
    $self->_setIptablesRule($gw, 0);

    my $failRatio = $fails / $probes;

    if ($failRatio >= $maxFailRatio) {
        $self->{failed}->{$gw} = 1;

        # Only generate event if gateway was not already disabled
        my $wasEnabled = $self->{gateways}->row($gw)->valueByName('enabled');
        return unless ($wasEnabled);

        my $disconnectMsg = __x('Gateway {gw} disconnected', gw => $gwName);
        my $reason =__x("'{type}' test to host '{host}' has failed {failRatio}%, max={maxFailRatio}%.",
                        failRatio => sprintf("%.2f", $failRatio*100),
                        type => $typeName, host => $host, maxFailRatio => $maxFailRatio*100);
        my $explanation = __('Gateway will be connected again if the test are passed.');
        my $event = new EBox::Event(message => "$disconnectMsg\n\n$reason\n$explanation",
                                    level   => 'error',
                                    source  => 'WAN Failover');
        push (@{$self->{eventList}}, $event);
    }
}

sub _runTest # (type, host)
{
    my ($self, $type, $host) = @_;

    my $result;

    if (($type eq 'gw_ping') or ($type eq 'host_ping')) {
        $result = system("ping -W5 -c1 $host");
    } elsif ($type eq 'dns') {
        $result = system("host -W 5 $host");
    } elsif ($type eq 'http') {
        my $command = "wget $host --tries=1 -T 5 -O /dev/null";
        $result = system($command);
    }

    return $result == 0;
}

sub _setIptablesRule # (gw, set)
{
    my ($self, $gw, $set) = @_;

    my $chain = 'FAILOVER-TEST';
    # Flush previous rules from custom chain. It'll fail silently
    # if it doesn't exist
    EBox::Sudo::silentRoot("/sbin/iptables -t mangle -F $chain");
    # Remove reference to custom chain from OUTPUT. It will aslo fail
    # silently if it doesn't exist
    EBox::Sudo::silentRoot("/sbin/iptables -t mangle -D OUTPUT -j $chain");

    if ($set) {
        # Create custom chain
        EBox::Sudo::silentRoot("/sbin/iptables -t mangle -N $chain");
        # Add refrence to custom chain from OUTPUT
        EBox::Sudo::silentRoot("/sbin/iptables -t mangle -A OUTPUT -j $chain");

        # We need to add a rule to return and do nothing
        # when the traffic is generated by ebox's apache
        my $apachePort = EBox::Global->modInstance('apache')->port();
        my $rule = "/sbin/iptables -t mangle -A $chain "
             . "-p tcp --source-port $apachePort -j RETURN";
        EBox::Sudo::root($rule);

        # Add rule to mark packets generated by ebox, i.e: failover tests
        my $mark = $self->{marks}->{$gw};
        $rule = "/sbin/iptables -t mangle -A $chain "
             . "-m owner --gid-owner ebox -j MARK --set-mark $mark";
        EBox::Sudo::root($rule);
    } else {
        # Delete custom chain. It'll fail silently if it doesn't exist
        EBox::Sudo::silentRoot("/sbin/iptables -t mangle -X $chain");
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

sub logIfDebug # (msg)
{
    my ($msg) = @_;

    if ($debug) {
        EBox::debug($msg);
    }
}

1;
