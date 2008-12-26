# Copyright (C) 2008 eBox Technologies S.L.
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

package EBox::Dashboard::Section;

use strict;
use warnings;

use EBox::Gettext;
use EBox::Exceptions::Internal;

sub new # (title?)
{
	my $class = shift;
	my $self = {};
	$self->{name} = shift;
	$self->{title} = shift;
    if(not defined($self->{name})) {
        throw EBox::Exceptions::Internal('Section must have a name');
    }
	bless($self, $class);
	return $self;
}

sub add # (item)
{
    my $self = shift;
    my $item = shift;
    $item->isa('EBox::Dashboard::Item') or
        throw EBox::Exceptions::Internal(
        "Tried to add a non-item to an EBox::Dashboard::Section");

    push(@{$self->items()}, $item);
}

sub items
{
    my ($self) = @_;
    unless (defined($self->{items})) {
        my @array = ();
        $self->{items} = \@array;
    }
    return $self->{items};
}

1;
