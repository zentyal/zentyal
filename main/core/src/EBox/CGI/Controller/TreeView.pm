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

use Data::Dumper; #FIXME

sub addNode
{
    my ($self) = @_;

    EBox::info("FIXME: implement add node");
    EBox::info(Dumper($self->getParams()));
}

sub deleteNode
{
    my ($self) = @_;

    EBox::info("FIXME: implement delete node");
    EBox::info(Dumper($self->getParams()));
}

sub editNode
{
    my ($self) = @_;

    EBox::info("FIXME: implement edit node");
    EBox::info(Dumper($self->getParams()));
}

# Group: Protected methods

sub _process
{
    my $self = shift;

    $self->_requireParam('action');
    my $action = $self->param('action');
    $self->{action} = $action;

    my $model = $self->{'model'};

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

    if ($self->{action} eq 'changeView') {
        my $global = EBox::Global->getInstance();
        return [ model => $self->{model}, hasChanged => $global->unsaved() ];
    } else {
        return [];
    }
}

1;
