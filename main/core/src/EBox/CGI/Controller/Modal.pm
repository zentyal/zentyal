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

#use base 'EBox::CGI::ClientRawBase';
use base 'EBox::CGI::Controller::DataTable';

use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::NotImplemented;
use EBox::Exceptions::Internal;

# Dependencies
use Error qw(:try);

sub new
{
    my ($class, %params) = @_;
    my $self = $class->SUPER::new(%params);
    $self->{'tableModel'} = $params{'tableModel'};
    bless($self, $class);
    return  $self;
}

sub getParams
{
    my ($self) = @_;

    my $tableDesc = $self->{'tableModel'}->table()->{'tableDescription'};

    my %params;
    foreach my $field (@{$tableDesc}) {
        foreach my $fieldName ($field->fields()) {
            my $value;
            if ( $field->allowUnsafeChars() ) {
                $value = $self->unsafeParam($fieldName);
            } else {
                $value = $self->param($fieldName);
            }
            # TODO Review code to see if we are actually checking
            # types which are not optional
            $params{$fieldName} = $value;
        }
    }

    $params{'id'} = $self->param('id');
    $params{'filter'} = $self->unsafeParam('filter');

    return %params;
}

# Method to refresh the table by calling rows method
sub refreshTable
{
    my ($self, $showTable, $action, @extraParams) = @_;
    my @params = @{ $self->_paramsForRefreshTable() };

    my $model = $self->{'tableModel'};
    $self->{template} = $model->modalViewer($showTable);
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

    my $parent    = $model->parent();
    my $id = $model->parentRow()->id();
    $parent->removeRow($id);
    $self->{json}->{success} = 1;
    $self->{json}->{rowId} = $id;
}

# Group: Protected methods

sub _process
{
    my ($self) = @_;

    $self->_requireParam('action');
    my $action = $self->param('action');
    my $firstShow = $self->param('firstShow');

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
        my $showTable = not $firstShow;
        my @extraParams;
        if ($selectCallerId and $firstShow) {
            @extraParams = (
                            selectForeignField => $selectForeignField,
                            foreignNextPageField => $foreignNextPageField,
                            nextPageContextName => $nextPageContextName,
                           );
        }
        $self->setMsg('');
        $self->refreshTable($showTable, $action, @extraParams);
    } elsif ($action eq 'cancelAdd') {
        $self->cancelAdd($model);
    } else {
        throw EBox::Exceptions::Internal("Action '$action' not supported");
    }
}

1;
