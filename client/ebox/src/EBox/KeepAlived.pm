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

package EBox::KeepAlived;

use base qw(EBox::AbstractDaemon);

use EBox;
use EBox::Global;
use EBox::Sudo qw( :all );

sub new
{
	my $class = shift;
	my $self = $class->SUPER::new(name => 'keepalive', @_);
	bless($self,$class);
	$self->{'interval'} = EBox::Config::configkey('keepalive_interval');
	return $self;
}

sub run
{
	my $self = shift;
	EBox::init();
	$self->init();

	my $global = EBox::Global->getInstance(1);
	my @names = @{$global->modNames};
	while(1) {
		foreach (@names) {
			my $mod = $global->modInstance($_);
			my $status = $mod->statusSummary;
			if (defined($status)) {
				if($mod->service() and (! $mod->isRunning())) {
					EBox::warn("Starting module " . $mod->name());
					$mod->restartService();
				}
			}
			sleep($self->{'interval'});
		}
	}
}
