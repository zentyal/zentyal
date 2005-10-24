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

package EBox::KeepAlive;

use strict;
use warnings;

use base qw(EBox::Module);

use EBox;
use EBox::Global;
use EBox::Sudo qw( :all );

sub _create
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'keepalive', @_);
	bless($self,$class);
	return $self;
}

sub _regenConfig
{
	_stopService();
	command(EBox::Config::libexec . 'ebox-keepalived');
}

sub _stopService
{
	my $pidfile = EBox::Config::tmp . "/pids/keepalive.pid";
	(-f $pidfile) or return;
	open(FD, $pidfile) or return;
	my $pid = <FD>;
	close(FD);
	kill(15, $pid);
}

1;
