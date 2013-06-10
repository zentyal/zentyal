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
use strict;
use warnings;

package EBox::CGI::Controller::TreeView;

use base 'EBox::CGI::ClientRawBase';

use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::NotImplemented;
use EBox::Exceptions::Internal;

use Error qw(:try);

sub new
{
    my $class = shift;
    my %params = @_;
    my $model = delete $params{'model'};
    my $template;
    if (defined ($model)) {
        $template = $model->Viewer();
    }

    my $self = $class->SUPER::new('template' => $template, @_);
    $self->{'model'} = $model;
    bless ($self, $class);

    return $self;
}

sub addNode
{
    my ($self) = @_;

    EBox::info("FIXME: implement add node, params: $self->{type} $self->{id}");
}

sub deleteNode
{
    my ($self) = @_;

    EBox::info("FIXME: implement delete node, params: $self->{type} $self->{id}");
}

sub editNode
{
    my ($self) = @_;

    EBox::info("FIXME: implement edit node, params: $self->{type} $self->{id}");
}

# Group: Protected methods

sub _process
{
    my $self = shift;

    $self->_requireParam('action');
    my $action = $self->param('action');
    $self->{action} = $action;

    $self->_requireParam('type');
    my $type = $self->param('type');
    $self->{type} = $type;

    $self->_requireParam('id');
    my $id = $self->unsafeParam('id');
    $self->{id} = $id;

    if ($action eq 'add') {
        $self->addNode();
    } elsif ($action eq 'delete') {
        $self->deleteNode();
    } elsif ($action eq 'edit') {
        $self->editNode();
    }

    $self->{'params'} = $self->masonParameters();
}

# Method: masonParameters
#
#      Overrides <EBox::CGI::ClientBase::masonParameters>
#
sub masonParameters
{
    my ($self) = @_;

    return [ model => $self->{model} ];
}

1;
