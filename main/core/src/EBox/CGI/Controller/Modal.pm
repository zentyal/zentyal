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

package EBox::CGI::Controller::Modal;
use base 'EBox::CGI::Controller::DataTable';

use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::NotImplemented;
use EBox::Exceptions::Internal;

use TryCatch;

sub new
{
    my ($class, %params) = @_;
    my $self = $class->SUPER::new(%params);
    $self->{'tableModel'} = $params{'tableModel'};
    bless($self, $class);
    return  $self;
}

sub refreshTable
{
    my ($self, $action, @extraParams) = @_;
    my @params = @{ $self->_paramsForRefreshTable() };

    my $model = $self->{'tableModel'};
    $self->{template} = $model->modalViewer();

    my $selectCallerId = $self->param('selectCallerId');
    if ($selectCallerId) {
        push @params, (selectCallerId => $selectCallerId);
    }

    push @params, @extraParams;

    $self->{'params'} = \@params;
}

sub cancelAdd
{
    my ($self, $model) = @_;
    my %params = $self->getParams();
    $self->{json} = {
        callParams => \%params,
        success => 0,
    };

    $model->removeRow($params{id});
    $self->{json}->{success} = 1;
}

sub addAction
{
    my ($self, %params) = @_;
    my %callParams = $self->getParams();
    $self->{json}->{success} = 0;
    $self->{json}->{callParams} = \%callParams;
    $self->{json}->{directory} = $params{directory};

    my $rowId = $self->addRow();

    $self->{json}->{rowId} = $rowId;
    $self->{json}->{success} = 1;
}

sub _process
{
    my ($self) = @_;

    $self->_requireParam('action');
    my $action = $self->param('action');

    my $selectCallerId = $self->param('selectCallerId');
    my $selectForeignField = $self->param('selectForeignField');

    my $nextPageContextName = $self->param('nextPageContextName');
    my $foreignNextPageField    = $self->param('foreignNextPageField');

    my $directory = $self->param('directory');

    my $model = $self->{'tableModel'};
    if ($directory) {
        $model->setDirectory($directory);
    }

    if ($action eq 'changeAdd') {
        my @extraParams = (
                            selectForeignField => $selectForeignField,
                            foreignNextPageField => $foreignNextPageField,
                            nextPageContextName => $nextPageContextName,
                           );
        $self->setMsg('');
        $self->refreshTable($action, @extraParams);
    } elsif ($action eq 'cancelAdd') {
        $self->cancelAdd($model);
    } elsif ($action eq 'add') {
        $self->addAction(directory => $directory);
    } else {
        throw EBox::Exceptions::Internal("Action '$action' not supported");
    }
}

1;
