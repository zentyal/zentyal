# Copyright (C) 2011 eBox Technologies S.L.
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

package EBox::Types::Action;

use strict;
use warnings;

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = {@_};

    bless($self, $class);
}

sub name()
{
    my ($self) = @_;
    return $self->{name};
}

sub printableValue()
{
    my ($self) = @_;
    return $self->{printableValue};
}

sub message
{
    my ($self) = @_;
    return $self->{message};
}

sub handle
{
    my ($self, %params) = @_;
    $self->{handler}->($self->{model}, $self, %params);
}

1;
