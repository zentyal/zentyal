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

package EBox::Test::RedisMock;

sub new
{
    my $class = shift;
    my $self = {};

    $self->{keys} = {};
    $self->{multi} = 0;
    $self->{queue} = [];

    bless ($self, $class);
    return $self;
}

sub set
{
    my ($self, $key, $value) = @_;

    if ($self->{multi}) {
        push (@{$self->{queue}}, { command => 'set', args => [ $key, $value ] });
    } else {
        $self->{keys}->{$key} = $value;
    }
}

sub get
{
    my ($self, $key) = @_;

    if ($self->{multi}) {
        return 'QUEUED';
    } else {
        return $self->{keys}->{$key};
    }
}

sub incr
{
    my ($self, $key) = @_;

    if ($self->{multi}) {
        push (@{$self->{queue}}, { command => 'set', args => [ $key ] });
    } else {
        $self->{keys}->{$key}++;
    }
}

sub del
{
    my ($self, $key) = @_;

    if ($self->{multi}) {
        push (@{$self->{queue}}, { command => 'del', args => [ $key ] });
    } else {
        delete $self->{keys}->{$key};
    }
}

sub keys
{
    my ($self, $pattern) = @_;

    if ($pattern =~ /\*$/) {
        chop ($pattern);
    }
    if ($pattern =~ /\/$/) {
        chop ($pattern);
    }

    my @filtered = grep { /^$pattern/ } keys %{$self->{keys}};
    return \@filtered;
}

sub __run_cmd
{
    my ($self, $command, $p1, $p2, $p3, @args) = @_;

    $self->$command(@args);
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

    foreach my $cmd (@{$self->{queue}}) {
        my $command = $cmd->{command};
        my @args = @{$cmd->{args}};
        $self->$command(@args);
    }

    $self->{queue} = [];

    return 1;
}

sub commit
{
}

sub discard
{
    my ($self) = @_;

    unless ($self->{multi}) {
        die "ERROR: discard called without multi";
    }

    $self->{queue} = [];
    $self->{multi} = 0;
}

1;
