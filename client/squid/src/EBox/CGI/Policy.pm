# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::CGI::Squid::Policy;

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
				      'template' => 'squid/policy.mas',
				      @_);
	$self->{domain} = 'ebox-squid';
	bless($self, $class);
	return $self;
}

sub _objectsToHash # (self, object) 
{
	my ($self, $objects) = @_;
	my $objectobj = EBox::Global->modInstance('objects');
	my @ret = ();
	foreach my $obj (@{$objects}) {
		my $item = {};
		$item->{name} = $obj;
		$item->{description} = $objectobj->ObjectDescription($obj);
		push(@ret, $item);
	}
	return \@ret;
}

sub _process($) {
	my $self = shift;
	$self->{title} = __('HTTP proxy policy');
	my $squid = EBox::Global->modInstance('squid');
	my $objectobj = EBox::Global->modInstance('objects');

	my @objects = @{$objectobj->ObjectNames};
	my @bans = @{$squid->bans};
	my @unfiltered = @{$squid->unfiltered};
	my @defaults = ();
	
	foreach (@objects) {
		if ($squid->isBan($_) or $squid->isUnfiltered($_)) {
			next;
		}
		push(@defaults, $_);
	}
		
	my @array = ();
	push (@array, 'bans' => $self->_objectsToHash(\@bans));
	push (@array, 'unfiltered' => $self->_objectsToHash(\@unfiltered));
	push (@array, 'defaults' => $self->_objectsToHash(\@defaults));
	$self->{params} = \@array;
}

1;
