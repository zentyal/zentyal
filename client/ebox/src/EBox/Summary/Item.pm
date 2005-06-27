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

package EBox::Summary::Item;

use strict;
use warnings;

use EBox::Exceptions::Internal;
use EBox::Gettext;

sub new 
{
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}

sub add # (item) 
{
	my $self = shift;
	my $item = shift;
	$item->isa('EBox::Summary::Item') or
		throw EBox::Exceptions::Internal(
		"Tried to add a non-item to an EBox::Summary::Item composite");

	push(@{$self->items}, $item);
}

sub items
{
	my $self = shift;
	unless (defined($self->{items})) {
		my @array = ();
		$self->{items} = \@array;
	}
	return $self->{items};
}

sub _htmlitems
{
	my $self = shift;
	foreach (@{$self->items}) {
		$_->html;
	}
}

sub html
{
	my $self = shift;
	$self->_htmlitems;
}

1;
