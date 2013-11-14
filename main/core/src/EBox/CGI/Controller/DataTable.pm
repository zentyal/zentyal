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

package EBox::CGI::Controller::DataTable;

use base 'EBox::CGI::ClientRawBase';

use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::NotImplemented;
use EBox::Exceptions::Internal;
use EBox::Html;
use POSIX qw(ceil);


# Dependencies
use Error qw(:try);

sub new
{
    my $class = shift;
    my %params = @_;
    my $tableModel = delete $params{'tableModel'};
    my $template;
    if (defined($tableModel)) {
        $template = $tableModel->Viewer();
    }

    my $self = $class->SUPER::new('template' => $template,
            @_);
    $self->{'tableModel'} = $tableModel;
    bless($self, $class);
    return  $self;
}

sub getParams
{
    my $self = shift;

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

    $params{'id'} = $self->unsafeParam('id');
    $params{'filter'} = $self->unsafeParam('filter');

    return %params;
}

sub _auditLog
{
    my ($self, $event, $id, $value, $oldValue) = @_;

    unless (defined $self->{audit}) {
        $self->{audit} = EBox::Global->modInstance('audit');
    }

    return unless $self->{audit}->isEnabled();

    my $model = $self->{tableModel};
    $value = '' unless defined $value;
    $oldValue = '' unless defined $oldValue;

    my ($rowId, $elementId) = split (/\//, $id);
    $elementId = $rowId unless defined ($elementId);
    my $row = $model->row($rowId);
    if (defined ($row)) {
        my $element;
        my $hash = $row->hashElements();
        if ($hash and exists $hash->{$elementId}) {
            $element = $hash->{$elementId};
        }

        my $type;
        if (defined ($element)) {
            $type = $element->type();
        }
        if ($type and ($type eq 'boolean')) {
            $value = $value ? 1 : 0;
            $oldValue = ($oldValue ? 1 : 0) if ($event eq 'set');
        } elsif (($type and ($type eq 'password')) or ($elementId eq 'password')) {
            $value = '****' if $value;
            $oldValue = '****' if $oldValue;
        }
    }

    $self->{audit}->logModelAction($model, $event, $id, $value, $oldValue);
}

sub addRow
{
    my ($self) = @_;

    my $model = $self->{'tableModel'};
    my %params = $self->getParams();

    if ($self->{json}) {
        $self->{json}->{callParams} = \%params;
    }

    my $id = $model->addRow(%params);

    my $cloneId =delete $params{cloneId};
    if ($cloneId) {
        my $newRow = $model->row($id);
        my $clonedRow = $model->row($cloneId);
        $newRow->cloneSubModelsFrom($clonedRow);
    }

    my $auditId = $self->_getAuditId($id);

    # We don't want to include filter in the audit log
    # as it has no value (it's a function reference)
    my %fields = map { $_ => 1 } @{ $model->fields() };
    delete $params{'filter'};
    foreach my $fieldName (keys %params) {
        my $value = $params{$fieldName};
        if ((not defined $value)) {
            # skip undef parameter which are not a field
            $fields{$fieldName} or
                next;
            # for boolean types undef means false
            my $instance = $model->fieldHeader($fieldName);
            $instance->isa('EBox::Types::Boolean') or
                next;
        }
        $self->_auditLog('add', "$auditId/$fieldName", $value);
    }

    return $id;
}

sub removeRow
{
    my ($self) = @_;

    my $model = $self->{'tableModel'};

    $self->_requireParam('id');
    my $id = $self->unsafeParam('id');
    my $force = $self->param('force');

    # We MUST get it before remove the item or it will fail.
   my $auditId = $self->_getAuditId($id);

    $model->removeRow($id, $force);

    $self->_auditLog('del', $auditId);
    return $id;
}

sub editField
{
    my ($self, %params) = @_;

    $self->_editField(0, %params);
}

sub _editField
{
    my ($self, $inPlace, %params) = @_;

    my $model = $self->{'tableModel'};
    my $force = $self->param('force');
    my $tableDesc = $model->table()->{'tableDescription'};

    my $id = $params{id};
    my $row = $model->row($id);
    my $auditId = $self->_getAuditId($id);

    $self->{json} = { success => 0 };

    # Store old and new values before setting the row for audit log
    my %changedValues;
    for my $field (@{$tableDesc} ) {
        my $fieldName = $field->fieldName();

        if ($inPlace and (not $field->isa('EBox::Types::Basic'))) {
            $row->valueByName($fieldName);
            $row->elementByName($fieldName)->storeInHash(\%params);
        }

        unless ($field->isa('EBox::Types::Boolean')) {
            next unless defined $params{$fieldName};
        }

        my $newValue = $params{$fieldName};
        my $oldValue = $row->valueByName($fieldName);

        next if ($newValue eq $oldValue);

        $changedValues{$fieldName} = {
            id => $id ? "$auditId/$fieldName" : $fieldName,
            new => $newValue,
            old => $oldValue,
        };
    }

    $model->setRow($force, %params);

    for my $fieldName (keys %changedValues) {
        my $value = $changedValues{$fieldName};
        $self->_auditLog('set', $value->{id}, $value->{new}, $value->{old});
    }

    my $editField = $self->param('editfield');
    if (not $editField) {
        $self->{json}->{success} = 1;

        $self->{json}->{changed} = {
            $id => $model->row($id)->schemaForJSON()
           };
        return;
    }

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
    my ($self) = @_;

    my $model = $self->{'tableModel'};
    my $id = $self->unsafeParam('id');
    my $boolField = $self->param('field');

    my $value = undef;
    if ($self->param('value')) {
        $value = 1;
    }

    my %editParams = (id => $id, $boolField => $value);
    # fill edit params with row fields
    my $row = $model->row($id);
    my $tableDesc =  $model->table()->{'tableDescription'};
    for my $field (@{$tableDesc} ) {
        my $fieldName = $field->fieldName();
        if ($fieldName eq $boolField) {
            next;
        }
        $editParams{$fieldName} = $row->valueByName($fieldName);
    }

    $self->_editField(1, %editParams);

    $model->popMessage();
}

sub setAllChecks
{
    my ($self, $value) = @_;
    my $model = $self->{'tableModel'};
    my $field = $self->param('editid');
    $model->setAll($field, $value);
}

sub checkAllControlValueAction
{
    my ($self) = @_;
    my $model = $self->{'tableModel'};
    my $field = $self->param('field');
    my $value = $model->checkAllControlValue($field) ? 1 : 0;
    $self->{json} = { success => $value  };
}

sub customAction
{
    my ($self, $action) = @_;
    my $model = $self->{'tableModel'};
    my %params = $self->getParams();
    my $id = $params{id};
    my $customAction = $model->customActions($action, $id);
    $customAction->handle($id, %params);

    $self->_auditLog('action', $id, $action);
}

# Method to refresh the table using standard print CGI method
sub refreshTable
{
    my ($self) = @_;
    $self->{'params'} = $self->_paramsForRefreshTable();
}

sub _htmlForRefreshTable
{
    my ($self) = @_;
    my $params = $self->_paramsForRefreshTable();
    my $html = EBox::Html::makeHtml($self->{template}, @{ $params});
    return $html;
}

sub _paramsForRefreshTable
{
    my ($self) = @_;
    my $model = $self->{'tableModel'};
    my $global = EBox::Global->getInstance();

    my $action =  $self->{'action'};
    my $filter = $self->unsafeParam('filter');
    my $page = $self->param('page');
    my $pageSize = $self->param('pageSize');
    if ( defined ( $pageSize )) {
        $model->setPageSize($pageSize);
    }

    my $editId;
    if ($action eq 'clone') {
        $editId = $self->param('id');
    } else {
        $editId = $self->param('editid');
    }

    my $rows = undef;
    my $tpages = 1000;
    my @params;
    push(@params, 'data' => $rows);
    push(@params, 'dataTable' => $model->table());
    push(@params, 'model' => $model);
    push(@params, 'action' => $action);
    push(@params, 'editid' => $editId);
    push(@params, 'hasChanged' => $global->unsaved());
    push(@params, 'filter' => $filter);
    push(@params, 'page' => $page);
    push(@params, 'tpages' => $tpages);

    return \@params;
}

sub editAction
{
    my ($self) = @_;
    my %params = $self->getParams();
    $self->editField(%params);
#    $self->refreshTable();
}

sub addAction
{
    my ($self, %params) = @_;
    $self->{json}->{success} = 0;

    my $rowId = $self->addRow();

    my $model  = $self->{'tableModel'};
    if ($params{json}) {
        # XXX this is for dialog mode..
        $self->{json}->{rowId} = $rowId;
        $self->{json}->{directory} = $params{directory};
        $self->{json}->{success} = 1;
    } elsif ($model->size() == 1) {
        # this was the first added row, reload all the table
        $self->{json}->{reload} = $self->_htmlForRefreshTable();
        $self->{json}->{success} = 1;
    } else {
        # XXX this calculations assumess than only one row is added
        # XXX add more pages when adding
        my $nAdded = 1;
        my $filter = $self->unsafeParam('filter');
        my $page   = $self->param('page');
        my $pageSize = $self->param('pageSize');
        my @ids    = @{ $self->_modelIds($model, $filter) };
        my $nPages =  ceil(scalar(@ids)/$pageSize);
        my $row    = $model->row($rowId);

        my $beginPrinted;
        my $endPrinted;
        my $needSpace;
        my $changedNPages;
        if ($page == 0) {
            $beginPrinted = 0;
        } else {
            $beginPrinted = ($page*$pageSize) + 1;
        }
        $endPrinted = $beginPrinted + $pageSize;
        if ($endPrinted > @ids) {
            $endPrinted = @ids;
        }

        my $befNPages =  ceil((@ids - $nAdded)/$pageSize);
        $changedNPages = $nPages != $befNPages;
        if (($page+1) == $nPages) {
            # to _not_ need space: be in last page and have rows left to reach
            # page size
            $needSpace = (($nPages*$pageSize) - @ids) < 0;
        } else {
            $needSpace = 1;
        }

        EBox::debug("nIds: " . scalar(@ids) . " pageSize: $pageSize: beginPrinted: $beginPrinted endPrinted: $endPrinted" );
        EBox::debug("needSpace $needSpace");
        EBox::debug("page: $page nPages $nPages befNPages: $befNPages:");

        my $rowPosition;
        for (my $i = $beginPrinted; $i < $endPrinted; $i++) {
            if ($ids[$i] eq $rowId) {
                if ($i == 0) {
                    $rowPosition = 'prepend';
                } else {
                    $rowPosition = $ids[$i-1];
                }
                last;
            }
        }
        if (not $rowPosition) {
            # cannot find the added row
            $self->{json}->{success} = 1;
            return;
        }

        EBox::debug("RowPosition $rowPosition");

        my $rowHtml = $self->_htmlForRow($model, $row, \@ids, $filter, $page);
        $self->{json}->{added} = [ { position => $rowPosition, row => $rowHtml } ];

        if ($needSpace) {
            # remove last row since it would not been seen, this assummes that only
            # one row is added at the time
            $self->{json}->{removed} = [ $ids[$endPrinted] ];
        }
        if ($changedNPages) {
            $self->{json}->{paginationChanges} = {
                page => $page + 1,
                nPages => $nPages,
                pageNumbersText => $model->pageNumbersText($page, $nPages),
               };
        }

        $self->{json}->{success} = 1;
    }
}

sub delAction
{
    my ($self) = @_;
    $self->{json} = {  success => 0 };
    my $rowId = $self->removeRow();

    my $reload = 0;
    my $model  = $self->{'tableModel'};
    my $nRows  = $model->size();

    if ($nRows == 0) {
        # all table rows removed, need to reload the table
        $reload = 1;
    } else {
        my $page   = $self->param('page');
        my $pageSize = $self->param('pageSize');
        my $nPagesBefore =  ceil(($nRows+1)/$pageSize);
        if (($page > 0) + (($page+1) >= $nPagesBefore ) ) {
        # TODO pagination changes du to removal in lastl page

            $reload = 1;
        } else {
        # TODO row changes whne removing rows and there are more pages left
        }

    }


    if ($reload) {
        $self->{json}->{reload} = $self->_htmlForRefreshTable();
        $self->{json}->{success} = 1;
    } else {
        $self->{json} = {
            success => 1,
            removed => [ $rowId ]
       };
    }
}

sub showChangeRowForm
{
    my ($self) = @_;
    my $model = $self->{'tableModel'};
    my $global = EBox::Global->getInstance();

    my $id     = $self->unsafeParam('editid');
    my $action =  $self->{'action'};

    my $filter = $self->unsafeParam('filter');
    my $page = $self->param('page');
    my $pageSize = $self->param('pageSize');
    my $tpages   = ceil($model->size()/$pageSize);

    my $presetParams = {};
    my $html = $self->_htmlForChangeRow($model, $action, $id, $filter, $page, $tpages, $presetParams);
    $self->{json} = {
        success => 1,
        changeRowForm => $html,
    };
}

sub changeAddAction
{
    my ($self) = @_;
    $self->showChangeRowForm();
}

sub changeListAction
{
    my ($self) = @_;
    # XXX?
    $self->refreshTable();
}

sub changeEditAction
{
    my ($self) = @_;
    if (not defined $self->param('editid')) {
        throw EBox::Exceptions::DataMissing(data => 'row ID');
    }
    $self->showChangeRowForm();
}

sub changeCloneAction
{
    my ($self) = @_;
    if (not defined $self->param('editid')) {
        throw EBox::Exceptions::DataMissing(data => 'clone row ID');
    }
    $self->showChangeRowForm();
}

# This action will show the whole table (including the
# table header similarly View Base CGI but inheriting
# from ClientRawBase instead of ClientBase
sub viewAction
{
    my ($self, %params) = @_;
    $self->{template} = $params{model}->Viewer();
    $self->refreshTable();
}

sub editBooleanAction
{
    my ($self) = @_;
    delete $self->{template}; # to not print standard response
    $self->editBoolean();

}

sub cloneAction
{
    my ($self) = @_;
    $self->refreshTable();
}

sub checkboxSetAllAction
{
    my ($self) = @_;
    $self->setAllChecks(1);
    $self->refreshTable();

}

sub checkboxUnsetAllAction
{
    my ($self) = @_;
    $self->setAllChecks(0);
    $self->refreshTable();
}

sub confirmationDialogAction
{
    my ($self, %params) = @_;

    my $actionToConfirm = $self->param('actionToConfirm');
    my %confirmParams = $self->getParams();
    my $res = $params{model}->_confirmationDialogForAction($actionToConfirm, \%confirmParams);
    my $msg;
    my $title = '';
    if (ref $res) {
        $msg = $res->{message};
        $title = $res->{title};
        defined $title or
            $title = '';

    } else {
        $msg = $res;
    }

    $self->{json} = {
        wantDialog => $msg ? 1 : 0,
        message => $msg,
        title => $title
       };
}

sub setPositionAction
{
    my ($self, %params) = @_;
    my $model = $params{model};

    $self->{json} = { success => 0};
    my $id     = $self->param('id');
    my $prevId = $self->param('prevId');
    (not $prevId) and $prevId = undef;
    my $nextId = $self->param('nextId');
    (not $nextId) and $nextId = undef;

    my $res = $model->moveRowRelative($id, $prevId, $nextId);
    $self->_auditLog('move', $self->_getAuditId($id), $res->[0], $res->[1]);

    $self->{json}->{success} = 1;
    $self->{json}->{unsavedModules} = EBox::Global->getInstance()->unsaved() ? 1 : 0;
}

# Group: Protected methods

sub _process
{
    my $self = shift;

    $self->_requireParam('action');
    my $action = $self->param('action');
    $self->{'action'} = $action;

    my $model = $self->{'tableModel'};

    my $directory = $self->param('directory');
    if ($directory) {
        $model->setDirectory($directory);
    }

    my $json = $self->param('json');
    if ($json) {
        $self->{json} = { success => 0  };
    }

    my $actionSub = $action . 'Action';
    if ($self->can($actionSub)) {
        $self->$actionSub(
            model => $model,
            directory => $directory,
            json      => $json,
           );
    } elsif ($model->customActions($action, $self->unsafeParam('id'))) {
        $self->customAction($action);
        $self->refreshTable()
    } else {
        throw EBox::Exceptions::Internal("Action '$action' not supported");
    }

    # json mode should not put messages in UI
    if ($self->{json}) {
        $model->setMessage('');
    }
}

sub _redirect
{
    my $self = shift;

    my $model = $self->{'tableModel'};

    return unless (defined($model));

    return $model->popRedirection();
}

# TODO: Move this function to the proper place
sub _printRedirect
{
    my $self = shift;
    my $url = $self->_redirect();
    return unless (defined($url));
    print "<script>window.location.href='$url'</script>";
}

sub _print
{
    my $self = shift;
    $self->SUPER::_print();
    unless ($self->{json}) {
        $self->_printRedirect;
    }
}

sub _getAuditId
{
    my ($self, $id) = @_;

    # Get parentRow id if any
    my $row = $self->{'tableModel'}->row($id);
    if (defined $row) {
        my $parentRow = $row->parentRow();
        if ($parentRow) {
            return $parentRow->id() . "/$id";
        }
    }
    return $id;
}

sub _htmlForRow
{
    my ($self, $model, $row, $ids, $filter, $page) = @_;
    my $table     = $model->table();

    my $html;
    my @params = (
        model => $model,
        row   => $row
   );

    my $nIds = scalar(@{$ids});
    push @params, (movable => $model->movableRows($filter, $nIds));
    push @params, (checkAllControls => $model->checkAllControls());

    push @params, (actions => $table->{actions});
    push @params, (withoutActions => $table->{withoutActions});
    push @params, (page => $page);
    push @params, (changeView => $model->action('changeView'));

    $html = EBox::Html::makeHtml('/ajax/row.mas', @params);
    return $html;
}

sub _htmlForChangeRow
{
    my ($self, $model, $action, $editId, $filter, $page, $tpages, $presetParams) = @_;
    my $table     = $model->table();

    my @params = (
        model  => $model,
        action => $action,

        editid => $editId,
        filter => $filter,
        page   => $page,
        tpages => $tpages,
        presetParams  => $presetParams
    );

    my $html;
    $html = EBox::Html::makeHtml('/ajax/changeRowForm.mas', @params);
    return $html;

}

sub _modelIds
{
    my ($self, $model, $filter) = @_;

    my $adaptedFilter;
    if (defined $filter and ($filter ne '')) {
        $adaptedFilter = $model->adaptRowFilter($filter);
    }
    my @ids;
    if (not $model->customFilter()) {
        @ids =  @{$model->ids()};
    } else {
        @ids = @{$model->customFilterIds($adaptedFilter)};
    }

    return \@ids;
}

1;
