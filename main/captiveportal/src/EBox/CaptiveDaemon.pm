# Copyright (C) 2011-2011 Zentyal S.L.
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

package EBox::CaptiveDaemon;

# Class: EBox::CaptiveDaemon
#
# This class is the daemon which is in charge of managing captive
# portal sessions. Iptables rules are added in order to let the users
# access the network.
#
# Already logged users rules are created at EBox::CaptivePortalFirewall so
# this daemons is only in charge of new logins and logouts / expired sessions

use strict;
use warnings;

use EBox::Config;
use EBox::Global;
use EBox::CaptivePortal;
use EBox::Sudo;
use Error qw(:try);
use EBox::Exceptions::DataExists;
use EBox::Util::Lock;
use Linux::Inotify2;

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

    # Create logout file
    EBox::Sudo::root('touch ' . EBox::CaptivePortal->LOGOUT_FILE);

    # wakeup on new session and logout events
    $notifier->watch(EBox::CaptivePortal->SIDS_DIR, IN_CREATE, sub {});
    $notifier->watch(EBox::CaptivePortal->LOGOUT_FILE, IN_CLOSE, sub {});

    # Don't die on ALARM signal
    local $SIG{ALRM} = sub {};

    while (1) {
        EBox::Util::Lock::lock('firewall');

        my @users = @{$self->{module}->currentUsers()};
        $self->_updateSessions(\@users);

        EBox::Util::Lock::unlock('firewall');

        # Sleep expiration interval
        alarm(EBox::CaptivePortal->EXPIRATION_TIME);
        $notifier->poll; # execution stalls here until alarm or login/out event
    }
}

# Method: _updateSessions
#
#   Init/finish user sessions and manage
#   firewall rules for them
#
sub _updateSessions
{
    my ($self, $currentUsers) = @_;
    my @rules;

    # firewall already inserted rules, checked to avoid duplicates
    my $iptablesRules = {
        captive  => join('', @{EBox::Sudo::root(IPTABLES . ' -t nat -n -L captive')}),
        icaptive => join('', @{EBox::Sudo::root(IPTABLES . ' -n -L icaptive')}),
        fcaptive => join('', @{EBox::Sudo::root(IPTABLES . ' -n -L fcaptive')}),
    };

    foreach my $user (@{$currentUsers}) {
        my $sid = $user->{sid};
        my $new = 0;

        # New sessions
        if (not exists($self->{sessions}->{$sid})) {
            $self->{sessions}->{$sid} = $user;
            push (@rules, @{$self->_addRule($user, $iptablesRules)});

            # bwmonitor...
            $self->_matchUser($user);

            $new = 1;
        }

        # Expired or quota exceeded
        if ($self->{module}->sessionExpired($user->{time}) or
            $self->{module}->quotaExceeded($user->{user}, $user->{bwusage})) {

            $self->{module}->removeSession($user->{sid});
            delete $self->{sessions}->{$sid};
            push (@rules, @{$self->_removeRule($user)});

            # bwmonitor...
            $self->_unmatchUser($user);

            next;
        }


        # Check for IP change
        unless ($new) {
            my $oldip = $self->{sessions}->{$sid}->{ip};
            my $newip = $user->{ip};
            unless ($oldip eq $newip) {
                # Ip changed, update rules
                push (@rules, @{$self->_addRule($user)});
                push (@rules, @{$self->_removeRule($self->{sessions}->{$sid})});

                # bwmonitor...
                $self->_matchUser($user);
                $self->_unmatchUser($self->{sessions}->{$sid});

                # update ip
                $self->{sessions}->{$sid}->{ip} = $newip;
            }
        }
    }

    EBox::Sudo::root(@rules);
}


sub _addRule
{
    my ($self, $user, $current) = @_;

    my $ip = $user->{ip};
    my $name = $user->{user};
    EBox::debug("Adding user $name with IP $ip");

    my $rule = $self->{module}->userFirewallRule($user);
    my @rules;
    push (@rules, IPTABLES . " -t nat -I captive $rule") unless($current->{captive} =~ / $ip /);
    push (@rules, IPTABLES . " -I fcaptive $rule") unless($current->{fcaptive} =~ / $ip /);
    push (@rules, IPTABLES . " -I icaptive $rule") unless($current->{icaptive} =~ / $ip /);
    return \@rules;
}

sub _removeRule
{
    my ($self, $user) = @_;

    my $ip = $user->{ip};
    my $name = $user->{user};
    EBox::debug("Removing user $name with IP $ip");

    my $rule = $self->{module}->userFirewallRule($user);
    my @rules;
    push (@rules, IPTABLES . " -t nat -D captive $rule");
    push (@rules, IPTABLES . " -D fcaptive $rule");
    push (@rules, IPTABLES . " -D icaptive $rule");

    return \@rules;
}


# Match the user in bwmonitor module
sub _matchUser
{
    my ($self, $user) = @_;

    if ($self->{bwmonitor} and $self->{bwmonitor}->isEnabled()) {
        try {
            $self->{bwmonitor}->addUserIP($user->{user}, $user->{ip});
        } catch EBox::Exceptions::DataExists with {}; # already in
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


###############
# Main program
###############

EBox::init();

EBox::info('Starting Captive Portal Daemon');
my $captived = new EBox::CaptiveDaemon();
$captived->run();

