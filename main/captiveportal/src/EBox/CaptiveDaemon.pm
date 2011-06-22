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

    my $captiveportal = EBox::Global->modInstance('captiveportal');


    # Setup iNotify to detect logins
    my $notifier = Linux::Inotify2->new()
        or die "unable to create new inotify object: $!";

    $notifier->watch(EBox::CaptivePortal->SIDS_DIR, IN_CLOSE_WRITE, sub {
        # do nothing, just wakeup
    });

    # Don't die on ALARM signal
    local $SIG{ALRM} = sub {};

    while (1) {
        EBox::Util::Lock::lock('firewall');

        my @users = @{$captiveportal->currentUsers()};
        $self->_updateSessions($captiveportal, \@users);

        EBox::Util::Lock::unlock('firewall');

        # Sleep expiration interval
        alarm(EBox::CaptivePortal->EXPIRATION_TIME-1);
        $notifier->poll; # execution stalls here until alarm or login event
    }
}

# Method: _updateSessions
#
#   Init/finish user sessions and manage
#   firewall rules for them
#
sub _updateSessions
{
    my ($self, $captiveportal, $currentUsers) = @_;
    my @rules;

    EBox::debug("Updating captiveportal sessions...");

    # firewall inserted rules, checked to avoid duplicates
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
            $new = 1;
        }

        # Expired
        if ($captiveportal->sessionExpired($user->{time})) {
            $captiveportal->removeSession($user->{sid});
            delete $self->{sessions}->{$sid};
            push (@rules, @{$self->_removeRule($user)});
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

                # update ip
                $self->{sessions}->{$sid}->{ip} = $newip;
            }
        }
    }

    EBox::Sudo::root(@rules);
    EBox::debug("DONE");
}


sub _addRule
{
    my ($self, $user, $current) = @_;

    my $ip = $user->{ip};
    my $name = $user->{user};
    my $rule = "-s $ip -m comment --comment 'user:$name' -j RETURN";

    EBox::debug("Adding user $name with IP $ip");

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

    my $rule = "-s $ip -m comment --comment 'user:$name' -j RETURN";
    my @rules;
    push (@rules, IPTABLES . " -t nat -D captive $rule");
    push (@rules, IPTABLES . " -D fcaptive $rule");
    push (@rules, IPTABLES . " -D icaptive $rule");

    return \@rules;
}


###############
# Main program
###############

EBox::init();

EBox::info('Starting Captive Portal Daemon');
my $captived = new EBox::CaptiveDaemon();
$captived->run();

