# Copyright (C) 2005-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::Menu::Node;

use EBox::Exceptions::Internal;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = {};
    bless($self, $class);
    $self->{style} = delete $opts{style};
    $self->{icon} = delete $opts{icon};
    $self->{tag} = delete $opts{tag};
    my $order = delete $opts{order};
    if (defined($order)) {
        $self->{order} = $order;
    } else {
        $self->{order} = 999;
    }
    $self->{items} = [];
    return $self;
}

sub add # (item)
{
    my ($self, $item) = @_;
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

    if(defined($self->{id})) {
        $item->{id} = $self->{id} . '_' . scalar(@{$self->{items}});
        my $i = 0;
        for my $it (@{$item->{items}}) {
            $it->{id} = $item->{id} . '_' . $i;
            $i++;
        }
    }
    push(@{$self->{items}}, $item);
}

sub items
{
    my ($self) = @_;

    my @sorted = sort { $a->{order} <=> $b->{order} } @{$self->{items}};

    return \@sorted;
}

sub _compare # (node)
{
    return undef;
}

sub _merge # (node)
{
    my ($self, $node) = @_;
    foreach my $item (@{$node->{items}}) {
        $self->add($item);
    }
}

sub html
{
    # default empty implementation
}

1;
