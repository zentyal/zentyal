# Copyright (C) 2013 Zentyal S.L.
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

use warnings;
use strict;
no strict 'refs';

package EBox::Test::RedisMock;

sub new
{
    my $class = shift;
    my $self = {};

    $self->{keys} = {};
    $self->{multi} = 0;

    bless ($self, $class);
}

sub set
{
    my ($self, $key, $value) = @_;

    $self->{keys}->{$key} = $value;
}

sub get
{
    my ($self, $key) = @_;

    return $self->{keys}->{$key};
}

sub incr
{
    my ($self, $key) = @_;

    $self->{keys}->{$key}++;
}

sub del
{
    my ($self, $key) = @_;

    delete $self->{keys}->{$key};
}

sub __send_command
{
    my ($self, $command, @args) = @_;

    $self->{response} = $self->$command(@args);
}

sub __read_response
{
    my ($self) = @_;

    delete $self->{response};
}

sub multi
{
    my ($self) = @_;

    $self->{multi} = 1;
}

sub exec
{
    my ($self) = @_;

    unless ($self->{multi}) {
        die "ERROR: exec called without multi";
    }

    $self->{multi} = 0;
    return 1;
}

sub discard
{
    my ($self) = @_;

    unless ($self->{multi}) {
        die "ERROR: discard called without multi";
    }

    $self->{multi} = 0;
}

1;
