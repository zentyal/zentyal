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

use constant INTERVAL => 60;

sub new
{
    my ($class) = @_;
    my $self = {};

    $self->{module} = EBox::Global->modInstance('captiveportal');
    $self->{users} = $self->{module}->model('Users');

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

    while (1) {
        my @ids = @{$self->{users}->ids()};

        my @allowedIPs;
        foreach my $id (@ids) {
            my $user = $self->{users}->row($id);
            push (@allowdIPs, $user->valueByName('ip'));
        }

        # Sleep interval
        sleep(INTERVAL);
    }
}


###############
# Main program
###############

EBox::init();
my $captived = new EBox::CaptiveDaemon();
$captived->run();

