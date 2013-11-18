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

sub addRow
{
    my $self = shift;

    my $model = $self->{'tableModel'};
    $model->addRow($self->getParams());
}

sub removeRow
{
    my $self = shift;

    my $model = $self->{'tableModel'};

    $self->_requireParam('id');
    my $id = $self->param('id');
    my $force = $self->param('force');

    $model->removeRow($id, $force);
}

sub editField
{
    my $self = shift;

    my $model = $self->{'tableModel'};
    my %params = $self->getParams();
    my $force = $self->param('force');
    $model->setRow($force, %params);

    my $editField = $self->param('editfield');
    if (not $editField) {
        return;
    }

    my $tableDesc = $self->{'tableModel'}->table()->{'tableDescription'};
    foreach my $field (@{$tableDesc}) {
        my $fieldName = $field->{'fieldName'};
        if ($editField ne $fieldName) {
            next;
        }
        my $fieldType = $field->{'type'};
        if ($fieldType  eq 'text' or $fieldType eq 'int') {
            $self->{'to_print'} = $params{$fieldName};
        }
    }

}

sub editBoolean
{
    my $self = shift;

    my $model = $self->{'tableModel'};
    my $id = $self->param('id');
    my $field = $self->param('field');
    my $value = 0;
    if ($self->param('value')) {
        $value = 1;
    }

    my $currentRow = $model->row($id);
    my $element = $currentRow->elementByName($field);
    $element->setValue($value);
    $model->setTypedRow( $id, { $field => $element}, readOnly => 0);
    $model->popMessage();
    my $global = EBox::Global->getInstance();
    # XXX Factor this class to be able to print 'application/json'
    #     and 'text/html' headers. This way we could just return
    #     a json object { changes_menu: true } and get it evaled
    #     using prototype. That's the right way :)
    if ($global->unsaved()) {
        $self->_responseToEnableChangesMenuElement();
    }
}

sub customAction
{
    my ($self, $action) = @_;
    my $model = $self->{'tableModel'};
    my %params = $self->getParams();
    my $id = $params{id};
    my $customAction = $model->customActions($action, $id);
    $customAction->handle($id, %params);
}

# Method to refresh the table by calling rows method
sub refreshTable
{
    my ($self, $showTable, $action, @extraParams) = @_;
    my @params = @{ $self->_paramsForRefreshTable() };


    my $model = $self->{'tableModel'};
    # my $global = EBox::Global->getInstance();

    # my $rows = undef;

    # my $editId;
    # if ($action eq 'clone') {
    #     $editId = $self->param('id');
    # } else {
    #     $editId = $self->param('editid');
    # }
    # my $page     = $self->param('page');
    # my $pageSize = $self->param('pageSize');
    # if ( defined $pageSize) {
    #     $model->setPageSize($pageSize);
    # }

    # my $filter = $self->unsafeParam('filter');
    # if (not defined $filter) {
    #     $filter = '';
    # }

    my $selectCallerId = $self->param('selectCallerId');

    $self->{template} = $model->modalViewer($showTable);

    # my @params = (
    #     'data' => $rows,
    #     'dataTable' => $model->table(),
    #     'model' => $model,
    #     'action' => $action,
    #     'editid' => $editId,
    #     'hasChanged' => $global->unsaved(),
    #     'filter' => $filter,
    #     'page' => $page,
    #     'tpages' => $tpages,
    #    );

    if ($selectCallerId) {
        push @params, (selectCallerId => $selectCallerId);
    }

    push @params, @extraParams;

    EBox::debug("refreshTable " . $self->{template});

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

    if ($action eq 'edit') {
        $self->editField();
        $self->refreshTable(1, $action);
    } elsif ($action eq 'add') {
        $self->addRow();
        $self->refreshTable(1, $action);
    } elsif ($action eq 'del') {
        $self->removeRow();
        $self->refreshTable(1, $action);
   } elsif ($action eq 'changeAdd') {
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
    } elsif ($action eq 'changeList') {
        $self->refreshTable(1, $action);
    } elsif ($action eq 'changeEdit') {
        $self->refreshTable(1, $action);
    } elsif ($action eq 'clone') {
        $self->refreshTable(1, $action);
    } elsif ($action eq 'view') {
        # This action will show the whole table (including the
        # table header similarly View Base CGI but inheriting
        # from ClientRawBase instead of ClientBase
        $self->refreshTable(1, $action);
     } elsif ($action eq 'editBoolean') {
         delete $self->{template};
         $self->editBoolean();
    } elsif ($action eq 'viewAndAdd') {
        $self->refreshTable(1, $action);
    } elsif ($action eq 'cancelAdd') {
        $self->cancelAdd($model);
#     } elsif ($model->customActions($action, $self->param('id'))) {
#         $self->customAction($action);
#         $self->refreshTable();
    } else {
        throw EBox::Exceptions::Internal("Action '$action' not supported");
    }

}

1;
