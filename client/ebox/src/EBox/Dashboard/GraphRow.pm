# Copyright (C) 2008 eBox Technologies S.L.
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
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA

package EBox::Dashboard::GraphRow;

use strict;
use warnings;

use base 'EBox::Dashboard::Item';
use EBox::Gettext;

sub new  # (name, value)
{
	my $class = shift;
	my $self = $class->SUPER::new();
	$self->{type} = 'graphrow';
	bless($self, $class);
	return $self;
}

sub add # (graph)
{
    my $self = shift;
    my $graph = shift;
    $graph->isa('EBox::Dashboard::Graph') or
        throw EBox::Exceptions::Internal(
        "Tried to add a non-graph to an EBox::Dashboard::GraphRow");

    $graph->{width} = 175;
    $graph->{height} = 100;

    push(@{$self->graphs()}, $graph);
}

sub graphs # ()
{
    my ($self) = @_;
    unless (defined($self->{graphs})) {
        my @array = ();
        $self->{graphs} = \@array;
    }
    return $self->{graphs};
}

sub HTMLViewer()
{
    return '/dashboard/graphrow.mas';
}

1;
