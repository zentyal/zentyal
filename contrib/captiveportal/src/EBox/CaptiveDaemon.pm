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

# Class: EBox::CaptiveDaemon
#
# This class is the daemon which is in charge of managing captive
# portal sessions. Iptables rules are added in order to let the users
# access the network.
#
# Already logged users rules are created at EBox::CaptivePortalFirewall so
# this daemons is only in charge of new logins and logouts / expired sessions
package EBox::CaptiveDaemon;

use EBox::CaptivePortal;
use EBox::CaptivePortal::Middleware::AuthLDAP;
use EBox::Config;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Global;
use EBox::Sudo;
use EBox::Util::Lock;
use EBox::Iptables;

use Linux::Inotify2;
use Time::HiRes qw(usleep);
use TryCatch::Lite;

# iptables command
use constant IPTABLES => '/sbin/iptables';

sub new
{
    my ($class) = @_;
    my $self = {};

    # Sessions already added to iptables (to trac ip changes)
    $self->{sessions} = {};
    $self->{module} = EBox::Global->modInstance('captiveportal');

    # Use bwmonitor if it exists
    if (EBox::Global->modExists('bwmonitor')) {
        $self->{bwmonitor} = EBox::Global->modInstance('bwmonitor');
    }

    $self->{pendingRules} = undef;

    bless ($self, $class);
    return $self;
}

# Method: run
#
#   Run the daemon. It never dies
#
sub run
{
    my ($self) = @_;

    # Setup iNotify to detect logins
    my $notifier = Linux::Inotify2->new();
    unless (defined($notifier)) {
        throw EBox::Exceptions::External('Unable to create inotify listener');
    }

    $notifier->blocking (0); # set non-block mode

    # Create logout file
    EBox::Sudo::root('touch ' . EBox::CaptivePortal->LOGOUT_FILE);

    # wakeup on new session and logout events
    $notifier->watch(EBox::CaptivePortal->SIDS_DIR, IN_CREATE, sub {});
    $notifier->watch(EBox::CaptivePortal->LOGOUT_FILE, IN_CLOSE, sub {});

    my $global = EBox::Global->getInstance(1);
    my $captive = $global->modInstance('captiveportal');
    $self->_checkChains($captive);

    my $expirationTime = $captive->expirationTime();

    my $exceededEvent = 0;
    my $events = $global->getInstance(1)->modInstance('events');
    try {
        if ((defined $events)  and ($events->isRunning())) {
            $exceededEvent =
                $events->isEnabledWatcher('EBox::Event::Watcher::CaptivePortalQuota');
        }
    } catch {
        $exceededEvent = 0;
    }

    my $timeLeft;
    while (1) {
        my @users = @{$self->{module}->currentUsers()};
        $self->_updateSessions(\@users, $events, $exceededEvent);

        my $endTime = time() + $expirationTime;
        while (time() < $endTime) {
            my $eventsFound = $notifier->poll();
            if ($eventsFound) {
                last;
            }
            usleep(80);
        }
    }
}

# Method: _updateSessions
#
#   Init/finish user sessions and manage
#   firewall rules for them
#
sub _updateSessions
{
    my ($self, $currentUsers, $events, $exceededEvent) = @_;
    my @rules;
    my @removeRules;
    my %sidsFromFWRules = %{ $self->{module}->currentSidsByFWRules() };

    foreach my $user (@{$currentUsers}) {
        my $sid = $user->{sid};
        my $new = (not exists($self->{sessions}->{$sid}));

        if ($new) {
            $self->{sessions}->{$sid} = $user;

            push @rules, @{$self->_addRule($user, $sid)};

            # bwmonitor...
            $self->_matchUser($user);

            if ($exceededEvent) {
                    $events->sendEvent(
                        message => __x('{user} has logged in captive portal and has quota left',
                                       user => $user->{'user'},
                                      ),
                        source  => 'captiveportal-quota',
                        level   => 'info',
                        dispatchTo => [ 'ControlCenter' ],
                        additional => {
                            outOfQuota => 0,
                            %{ $user }, # all fields from CaptivePortal::Model::Users::currentUsers
                           }
                       );
                }
        }

        # Check for expiration or quota exceeded
        my $quotaExceeded = $self->{module}->quotaExceeded($user->{user}, $user->{bwusage}, $user->{quotaExtension});
        if ($quotaExceeded or $self->{module}->sessionExpired($user->{time})  ) {
            EBox::CaptivePortal::Middleware::AuthLDAP::removeSession($user->{sid});
            delete $self->{sessions}->{$sid};
            push (@removeRules, @{$self->_removeRule($user, $sid)});

            # bwmonitor...
            $self->_unmatchUser($user);

            if ($quotaExceeded) {
                if ($exceededEvent) {
                    $events->sendEvent(
                        message => __x('{user} is out of quota in captive portal with a usage of {bwusage} Mb',
                                       user => $user->{'user'},
                                       bwusage => $user->{'bwusage'}
                                      ),
                        source  => 'captiveportal-quota',
                        level   => 'warn',
                        additional => {
                             outOfQuota => 1,
                            %{ $user }, # all fields from CaptivePortal::Model::Users::currentUsers
                        }
                       );
                }
            }
        } else {
            # Check for IP change or missing rule
            my $notFWRules = 0;
            if (not $new) {
                $notFWRules = not exists $sidsFromFWRules{$sid};
            }
            my $oldip = $self->{sessions}->{$sid}->{ip};
            my $newip = $user->{ip};
            my $changedIP = $oldip ne $newip;
            if ($changedIP) {
                # Ip changed, remove old rules
                push (@rules, @{$self->_removeRule($self->{sessions}->{$sid}), $sid});

                # bwmonitor...
                $self->_matchUser($user);
                $self->_unmatchUser($self->{sessions}->{$sid});

                # update ip
                $self->{sessions}->{$sid}->{ip} = $newip;
            }
            if ($changedIP or $notFWRules) {
                push (@rules, @{$self->_addRule($user, $sid)});
            }

        }

        delete $sidsFromFWRules{$sid};
    }

    # check and remove leftover rules
    while (my ($sid, $rulesByChain) = each %sidsFromFWRules) {
        my $prevRule;
        while (my ($chain, $rule) = each %{ $rulesByChain }) {
            if (($prevRule->{user} eq $rule->{user}) and
                ($prevRule->{ip}   eq $rule->{ip})   and
                ($prevRule->{mac}  eq $rule->{mac})
               ) {
                # same rule, we have already rules to remove it
                next;
            }
            $prevRule = $rule;
            push @removeRules, @{ $self->_removeRule($rule, $sid) };
        }
    }

    if (@rules or @removeRules or $self->{pendingRules}) {
        # try to get firewall lock
        my $lockedFw = 0;
        try {
            EBox::Util::Lock::lock('firewall');
            $lockedFw = 1;
        } catch {
        }

        if ($lockedFw) {
            try {
                my @rulesToExecute = ();
                if ($self->{pendingRules}) {
                    @rulesToExecute = @{ $self->{pendingRules} };
                    $self->{pendingRules} = undef;
                }
                push @rulesToExecute, @rules, @removeRules;
                foreach my $rule (@rulesToExecute) {
                    EBox::Sudo::silentRoot($rule);
                    if ($? != 0) {
                        # ignore error and continue with next rule
                        EBox::debug("Cannot execute captive portal fw rule: $rule");
                    }
                }
            } catch ($e) {
                EBox::Util::Lock::unlock('firewall');
                $e->throw();
            }
            EBox::Util::Lock::unlock('firewall');
        } else {
            $self->{pendingRules} or $self->{pendingRules} = [];
            push @{ $self->{pendingRules} }, @rules, @removeRules;
            EBox::error("Captive portal cannot lock firewall, we will try to add pending firewall rules later. Users access could be inconsistent until rules are added");
        }
    }
}

sub _addRule
{
    my ($self, $user, $sid) = @_;

    my $ip = $user->{ip};
    my $name = $user->{user};
    EBox::debug("Adding user $name with IP $ip");

    my $rule = $self->{module}->userFirewallRule($user, $sid);

    my @rules;
    push (@rules, IPTABLES . " -t nat -I captive $rule");
    push (@rules, IPTABLES . " -I fcaptive $rule");
    push (@rules, IPTABLES . " -I icaptive $rule");
    # conntrack remove redirect conntrack (this will remove
    # conntrack state for other connections from the same source but it is not
    # important)
    push (@rules, "conntrack -D -p tcp --src $ip");

    return \@rules;
}

sub _removeRule
{
    my ($self, $user, $sid) = @_;

    my $ip = $user->{ip};
    my $name = $user->{user};

    my $rule = $self->{module}->userFirewallRule($user, $sid);
    EBox::debug("Removing user $name with IP $ip base rule $rule");
    my @rules;
    push (@rules, IPTABLES . " -t nat -D captive $rule");
    push (@rules, IPTABLES . " -D fcaptive $rule");
    push (@rules, IPTABLES . " -D icaptive $rule");
    # remove conntrack (this will remove conntack state for other connections
    # from the same source but it is not important)
    push (@rules, "conntrack -D --src $ip");

    return \@rules;
}

# Match the user in bwmonitor module
sub _matchUser
{
    my ($self, $user) = @_;

    if ($self->{bwmonitor} and $self->{bwmonitor}->isEnabled()) {
        try {
            $self->{bwmonitor}->addUserIP($user->{user}, $user->{ip});
        } catch (EBox::Exceptions::DataExists $e) {
            # already in
        }
    }
}

# Unmatch the user in bwmonitor module
sub _unmatchUser
{
    my ($self, $user) = @_;

    if ($self->{bwmonitor} and $self->{bwmonitor}->isEnabled()) {
        $self->{bwmonitor}->removeUserIP($user->{user}, $user->{ip});
    }
}

# checks if all chains are in place and put them if dont exists
sub _checkChains
{
    my ($self, $captive) = @_;

    my $fwHelper = $captive->firewallHelper();
    my $chains   = $fwHelper->chains();

    my $chainsInPlace = 1;
    while(my ($table, $chains_list) = each %{$chains}) {
        foreach my $ch (@{ $chains_list }) {
            EBox::Sudo::silentRoot("iptables -t $table -nL $ch");
            $chainsInPlace = ($? == 0);
        }
        if (not $chainsInPlace) {
            next;
        }
    }

    if ($chainsInPlace) {
        return;
    }

    # remove chains to be sure they are not leftovers
    while(my ($table, $chains_list) = each %{$chains}) {
        foreach my $ch (@{ $chains_list }) {

            EBox::Sudo::silentRoot("iptables -t $table -F $ch",
                             "iptables -t $table -X $ch");
        }
    }

    my $iptables = EBox::Iptables->new();
    $iptables->executeModuleRules($captive);
}


###############
# Main program
###############

EBox::init();

EBox::info('Starting Captive Portal Daemon');
my $captived = new EBox::CaptiveDaemon();
$captived->run();

