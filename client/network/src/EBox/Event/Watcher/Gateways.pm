# Copyright (C) 2009 eBox Technologies S.L.
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
#        array ref - <EBox::Event> an info event is sent if eBox is up and
#        running and a fatal event if eBox is down
#
sub run
{
    my ($self) = @_;

    #EBox::debug('Entering failover event...');

    $self->{eventList} = [];
    $self->{failed} = {};

    my $global = EBox::Global->getInstance();
    my $network = $global->modInstance('network');

    return [] unless $network->isEnabled();

    # We don't do anything if there are unsaved changes
    return [] if $global->modIsChanged('network');

    my $rules = $network->model('WANFailoverRules');
    my $gateways = $network->model('GatewayTable');
    $self->{gateways} = $gateways;
    $self->{marks} = $network->marksForRouters();

    foreach my $id (@{$rules->enabledRows()}) {
        #EBox::debug("Testing rules for gateway with id $id...");
        my $row = $rules->row($id);
        $self->_testRule($row);
    }

    # We don't do anything if there are unsaved changes
    return [] if $global->modIsChanged('network');

    #EBox::debug('Applying changes in the gateways table...');

    my $needSave = 0;
    foreach my $id (@{$gateways->ids()}) {
        my $row = $gateways->row($id);
        my $gwName = $row->valueByName('name');
        my $enabled = $row->valueByName('enabled');

        # It must be enabled if all tests are passed
        my $enable = not($self->{failed}->{$id});

        #EBox::debug("Properties for gateway $gwName ($id): enabled=$enabled, enable=$enable");

        # We don't do anything if the previous state is the same
        if ($enable xor $enabled) {
            $row->elementByName('enabled')->setValue($enable);
            $row->store();
            $needSave = 1;
            if ($enable) {
                my $event = new EBox::Event(message => __x("Gateway {gw} connected", gw => $gwName),
                                    level   => 'info',
                                    source  => $self->name());
                push (@{$self->{eventList}}, $event);
            }
        }
    }

    # Check if default gateway has been disabled and choose another
    my $default = $gateways->findValue('default' => 1);

    unless ($default and $default->valueByName('enabled')) {
        # If the original default gateway is alive, restore it
        my $originalId = $network->selectedDefaultGateway();
        #EBox::debug("The preferred default gateway is $originalId");
        my $original = $gateways->row($originalId);
        if ($original and $original->valueByName('enabled')) {
            $default->elementByName('default')->setValue(0);
            $default->store();
            $original->elementByName('default')->setValue(1);
            $original->store();
            #EBox::debug('The original default gateway has been restored');
            $needSave = 1;
        } else {
            #EBox::debug('Checking if there is another enabled gateway to set as default');
            # Check if we can find another enabled to set it as default
            my $other = $gateways->findValue('enabled' => 1);
            if ($other) {
                $default->elementByName('default')->setValue(0);
                $default->store();
                $other->elementByName('default')->setValue(1);
                $other->store();
                my $otherName = $other->valueByName('name');
                #EBox::debug("The gateway $otherName is now the default");
                $needSave = 1;
            }
        }
    }

    if ($needSave) {
        #EBox::debug('Regenerating rules for the gateways');
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
        #EBox::debug('No need to regenerate the rules for the gateways');
    }

    #EBox::debug('Leaving failover event...');

    return $self->{eventList};
}

sub _testRule # (row)
{
    my ($self, $row) = @_;

    my $gw = $row->valueByName('gateway');

    #EBox::debug("Entering _testRule for gateway $gw...");

    # First test on this gateway, initialize its entry on the hash
    unless (exists $self->{failed}->{$gw}) {
        $self->{failed}->{$gw} = 0;
    }

    # If a test for this gw has already failed we don't test any other
    return if ($self->{failed}->{$gw});

    #EBox::debug("Running $typeName tests for gateway $gw...");

    my $gwName = $self->{gateways}->row($gw)->valueByName('name');

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
            #EBox::debug("Probe number $_ succeded.");
            $successes++;
            last if ($successes >= $neededSuccesses);
        } else {
            #EBox::debug("Probe number $_ failed.");
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

        my $event = new EBox::Event(message => __x("Gateway {gw} disconnected ({failRatio}% of '{type}' tests to host '{host}' failed, max={maxFailRatio}%)",
                                             gw => $gwName,
                                             failRatio => $failRatio*100,
                                             type => $typeName,
                                             host => $host,
                                             maxFailRatio => $maxFailRatio*100),
                                    level   => 'error',
                                    source  => $self->name());
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
        my $command = "wget $host -T 5 -O /dev/null";
        $result = system($command);
    }

    return $result == 0;
}

sub _setIptablesRule # (gw, set)
{
    my ($self, $gw, $set) = @_;

    # We add or delete the rule based on 'set' argument
    my $action = $set ? '-A' : '-D';

    my $mark = $self->{marks}->{$gw};

    my $rule = "/sbin/iptables -t mangle $action OUTPUT "
             . "-m owner --gid-owner ebox -j MARK --set-mark $mark";

    #EBox::debug("Setting rule: $rule\n");
    EBox::Sudo::root($rule);
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
