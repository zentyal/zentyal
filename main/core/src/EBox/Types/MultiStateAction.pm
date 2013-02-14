# Copyright (C) 2011-2012 eBox Technologies S.L.
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

package EBox::Types::MultiStateAction;

sub new
{
    my $class = shift;
    my %opts = @_;

    my $self = {@_};

    unless ($self->{'acquirer'} or $self->{'defaultState'}) {
        throw EBox::Exceptions::MissingArgument('acquirer');
    }

    unless (defined ($self->{enabled})) {
        $self->{enabled} = 1;
    }

    bless ($self, $class);

    return $self;
}

sub state
{
    my ($self, $id) = @_;
    my $state;

    if ($self->{'acquirer'}) {
        $state = $self->{'acquirer'}->($self->{model}, $id);
    } elsif ($self->{'defaultState'}) {
        $state = $self->{'defaultState'};
    } else {
        $state = (keys %{$self->{'states'}})[0];
    }

    return $state;
}

sub action
{
    my ($self, $id) = @_;

    my $stateName = $self->state($id);
    # XXX: Dependency cycle, Action inherits from MultiStateAction
    my $state = $self->{states}->{$stateName};
    my $action = new EBox::Types::Action(
        name => $state->{name},
        printableValue => $state->{printableValue},
        handler => $state->{handler},
        image => $state->{image},
        message => $state->{message},
        enabled => $state->{enabled},
        model => $self->{model},
    );

    return $action;
}

sub name
{
    my ($self, $id) = @_;
    return $self->action($id)->{name};
}

sub printableValue
{
    my ($self, $id) = @_;
    return $self->action($id)->{printableValue};
}

sub message
{
    my ($self, $id) = @_;
    return $self->action($id)->{message};
}

sub handle
{
    my ($self, $id, %params) = @_;
    $self->action($id)->{handler}->($self->{model}, $self, $id, %params);
}

sub image
{
    my ($self, $id, %params) = @_;
    my $image = $self->action($id)->{image};
    $image = '/data/images/run.gif' unless ($image);
    return $image;
}

sub enabled
{
    my ($self, $id) = @_;

    my $action = $self->action($id);
    my $enabled = $action->{enabled};
    if (ref $enabled) {
        $enabled = &$enabled;
    }
    return $enabled;
}

sub onclick
{
    my ($self, $id) = @_;
    my $onclick;
    my $handler = $self->action($id)->{onclick};

    if ($handler) {
        $onclick = $handler->($self->{model}, $id);
    }

    unless ($onclick) {
        $onclick = $self->{model}->customActionClickedJS($self->name($id), $id);
        $onclick .= '; return false';
    }
    return $onclick;
}

sub template
{
    my ($self) = @_;

    return $self->{template} if ($self->{template});
    return '/input/action.mas';
}

1;
