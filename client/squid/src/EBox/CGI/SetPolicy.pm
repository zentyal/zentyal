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

package EBox::CGI::Squid::SetPolicy;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title'    => __('HTTP proxy policy'),
				      @_);
	$self->{domain} = 'ebox-squid';
	$self->{redirect} = 'Squid/Policy';
	$self->{errorchain} = 'Squid/Policy';
	bless($self, $class);
	return $self;
}

sub trimArray() # (@array)
{
	my $self = shift;
	my @array = @_;
	my @ret = ();
	foreach my $elmnt (@array) {
		defined ($elmnt) or next;
		($elmnt ne '') or next;
		push(@ret, $elmnt);
	}
	return @ret;
}

sub _process($) 
{
	my $self = shift;
	my $squid = EBox::Global->modInstance('squid');

	my @bans = @{$squid->bans};
	my @unfiltered = @{$squid->unfiltered};
	
	if (defined($self->param('unfilteredToFiltered'))) {
		my @remove = $self->trimArray($self->param('unfiltered'));
		(@remove < 1) and return;
		my @newunfiltered = ();
		foreach my $obj (@unfiltered) {
			unless (grep(/^$obj$/, @remove)) {
				push(@newunfiltered, $obj)
			}
		}
		$squid->setUnfiltered(\@newunfiltered);
	} elsif (defined($self->param('filteredToBanned'))) {
		my @add = $self->trimArray($self->param('defaults'));
		(@add < 1) and return;
		foreach my $obj (@add) {
			unless(grep(/^$obj$/, @bans)) {
				push(@bans, $obj);
			}
		}
		$squid->setBans(\@bans);

	} elsif (defined($self->param('filteredToUnfiltered'))) {
		my @add = $self->trimArray($self->param('defaults'));
		(@add < 1) and return;
		foreach my $obj (@add) {
			unless(grep(/^$obj$/, @unfiltered)) {
				push(@unfiltered, $obj);
			}
		}
		$squid->setUnfiltered(\@unfiltered);

	} elsif (defined($self->param('bannedToFiltered'))) {
		my @remove = $self->trimArray($self->param('bans'));
		(@remove < 1) and return;
		my @newbans = ();
		foreach my $obj (@bans) {
			unless (grep(/^$obj$/, @remove)) {
				push(@newbans, $obj)
			}
		}
		$squid->setBans(\@newbans);
	} 
}

1;
