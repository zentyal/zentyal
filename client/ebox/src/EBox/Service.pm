# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::Service;

use strict;
use warnings;

use EBox::Sudo qw( :all );

#
#   Function: manage
#
#	Manage daemons
#
#   Parameters:
#   	
#   	daemon - name of the daemon
#   	action - [start|stop|restart]
#
#   Exceptions:
#
#       Internal - Bad argument
#
sub manage # (daemon,action)
{
	my ($daemon, $action) = @_;
	(-d "/var/service/$daemon") or
		throw EBox::Exceptions::Internal("No such daemon: $daemon");

	if ( $action eq 'start' ) {
		root("/usr/bin/runsvctrl up /var/service/$daemon");
	}
	elsif ( $action eq 'stop' ) {
		root("/usr/bin/runsvctrl down /var/service/$daemon");
	}
	elsif ( $action eq 'restart') {
		root("/usr/bin/runsvctrl down /var/service/$daemon");
		root("/usr/bin/runsvctrl up /var/service/$daemon");
	}
	else {
		throw EBox::Exceptions::Internal("Bad argument: $action");
	}
}

#
#   Function: running
#
#	Check if a daemon is running
#
#   Parameters:
#   	
#   	daemon - name of the daemon
#
#   Exceptions:
#
#       Internal - Bad argument
#
sub running # (daemon)
{
	my ($daemon) = @_;
	(-d "/var/service/$daemon") or
		throw EBox::Exceptions::Internal("No such daemon: $daemon");

	my $output = root("/usr/bin/runsvstat /var/service/$daemon");
	my $status = @{$output}[0];
	if ($status =~ m{^/var/service/$daemon: run}) {
		return 1;
	} elsif ($status =~ m{^/var/service/$daemon: down}) {
		return undef;
	} else {
		throw EBox::Exceptions::Internal("Error getting status: $daemon");
	}
}

1;
