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

package EBox::Menu::Node;

use strict;
use warnings;

use EBox::Exceptions::Internal;
use EBox::Gettext;

sub new 
{
	my $class = shift;
	my %opts = @_;
	my $self = {};
	bless($self, $class);
	$self->{style} = delete $opts{style};
	my $order = delete $opts{order};
	if (defined($order) and ($order > 0) and ($order <= 10)) {
		$self->{order} = $order;
	} else {
		$self->{order} = 5;
	}
	$self->{items} = [];
	return $self;
}

sub add # (item) 
{
	my $self = shift;
	my $item = shift;
	(defined($item)) or return;
	$item->isa('EBox::Menu::Node') or
		throw EBox::Exceptions::Internal(
	"Tried to add an unknown object to an EBox::Menu::Node composite");

	foreach my $i (@{$self->{items}}) {
		if ($i->_compare($item)) {
			$i->_merge($item);
			return;
		}
	}

	push(@{$self->{items}}, $item);
}

sub items
{
	my $self = shift;
	my @array = ();
	foreach my $i (1..10) {
		foreach my $item (@{$self->{items}}) {
			if ($item->{order} == $i) {
				push(@array, $item);
			}
		}
	}
	return \@array;
}

sub _compare # (node)
{
	return undef;
}

sub _merge # (node)
{
	my ($self, $node) = @_;
	push(@{$self->{items}}, @{$node->{items}});
}

sub html
{
	# default empty implementation
}

1;
