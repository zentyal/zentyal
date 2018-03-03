# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2014 Zentyal S.L.
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
use EBox::Exceptions::DataInUse;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::Internal;
use EBox::Html;
use EBox::View::StackTrace;
use EBox::TraceStorable;

use POSIX qw(ceil floor INT_MAX);
use TryCatch;
use JSON::XS;
use Perl6::Junction qw(all any);

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
            if ($field->allowUnsafeChars()) {
                $value = $self->unsafeParam($fieldName);
            } else {
                $value = $self->param($fieldName);
            }
            # TODO Review code to see if we are actually checking
            # types which are not optional
            $params{$fieldName} = $value;
        }
    }

    $params{'id'}     = $self->unsafeParam('id');
    $params{'filter'} = $self->unsafeParam('filter');

    return %params;
}

sub _pageSize
{
    my ($self) = @_;
    my $pageSize = $self->param('pageSize');
    unless ($pageSize) {
        $pageSize = $self->{tableModel}->pageSize($self->user());
    }
    if ($pageSize eq '_all') {
        return INT_MAX; # could also be size but maximum int avoids the call
    }

    return $pageSize;
}

sub _auditLog
{
    my ($self, $event, $id, $value, $oldValue) = @_;

    unless (defined $self->{audit}) {
        $self->{audit} = EBox::Global->modInstance('audit');
    }
    return unless $self->{audit}->isEnabled();

    my $model = $self->{tableModel};
    return unless $model->auditable();

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
        } elsif (ref($value) or ref($oldValue)) {
            my $encoder = new JSON::XS()->utf8()->allow_blessed(1)->convert_blessed(1);
            $value = $encoder->encode($value) if ref($value);
            $oldValue = $encoder->encode($oldValue) if ref($oldValue);
        }

    }
    $self->{audit}->logModelAction($model, $event, $id, $value, $oldValue);
}

sub addRow
{
    my ($self) = @_;

    my $model = $self->{'tableModel'};
    my %params = $self->getParams();
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

    return $self->_editField(0, %params);
}

sub _editField
{
    my ($self, $inPlace, %params) = @_;

    my $model = $self->{'tableModel'};
    my $force = $self->param('force');

    my $id = $params{id};
    my $row = $model->row($id);
    my $auditId = $self->_getAuditId($id);

    my $viewCustomizer = $model->viewCustomizer();
    my $triggerFields = $viewCustomizer->onChangeFields();
    # Fetch trigger fields
    foreach my $name (keys %{$triggerFields}) {
        $triggerFields->{$name} = $params{$name};
    }

    # Store old and new values before setting the row for audit log
    my %changedValues;
    foreach my $field (@{$row->elements()}) {
        my $fieldName = $field->fieldName();

        if ($inPlace and (not $field->isa('EBox::Types::Basic'))) {
            $row->valueByName($fieldName);
            $row->elementByName($fieldName)->storeInHash(\%params);
        }

        unless ($field->isa('EBox::Types::Boolean')) {
            # Check all fields are in the params
            my @fields = $field->fields();
            my $seen = grep { defined ($params{$_})} @fields;
            next if ($seen != scalar(@fields));
        }

        # Skip fields that are hidden or disabled by the view customizer
        next if($viewCustomizer->skipField($fieldName, $triggerFields));

        my $newField = $field->clone();
        $newField->setMemValue(\%params);
        my $newValue = $newField->value();
        my $oldValue = $row->valueByName($fieldName);

        next if ($row->elementByName($fieldName)->isEqualTo($newField));

        $changedValues{$fieldName} = {
            id => $id ? "$auditId/$fieldName" : $fieldName,
            new => $newValue,
            old => $oldValue,
        };
    }

    try {
        $model->setRow($force, %params);
    } catch (EBox::Exceptions::DataInUse $e) {
        $self->{json}->{success} = 1;
        $self->{json}->{dataInUseForm} = $self->_htmlForDataInUse(
            $model->table()->{actions}->{editField},
            "$e",
           );
        return $id;
    }

    for my $fieldName (keys %changedValues) {
        my $value = $changedValues{$fieldName};
        $self->_auditLog('set', $value->{id}, $value->{new}, $value->{old});
    }

    my $editField = $self->param('editfield');
    if (not $editField) {
        return $id;
    }

    foreach my $field (@{$row->elements()}) {
        my $fieldName = $field->{'fieldName'};
        if ($editField ne $fieldName) {
            next;
        }
        my $fieldType = $field->{'type'};
        if ($fieldType  eq 'text' or $fieldType eq 'int') {
            $self->{'to_print'} = $params{$fieldName};
        }
    }

    return $id;
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
    for my $field (@{$row->elements()}) {
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
    my ($self) = @_;
    my $model = $self->{'tableModel'};
    my $field = $self->param('editid');
    my $value = $self->param($field);
    $model->setAll($field, $value);
    return $value;
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

#  Method: _htmlForRefreshTable
#
#  Parameters:
#     page - optional parameter for force the rendering of arbitrary page
#            instead of the actual one
sub _htmlForRefreshTable
{
    my ($self, $page) = @_;
    my $params = $self->_paramsForRefreshTable($page);
    my $html = EBox::Html::makeHtml($self->{template}, @{ $params});
    return $html;
}

sub _paramsForRefreshTable
{
    my ($self, $forcePage) = @_;
    my $model = $self->{'tableModel'};
    my $global = EBox::Global->getInstance();

    my $action = $self->{'action'};
    my $filter = $self->unsafeParam('filter');
    my $page = defined $forcePage ? $forcePage : $self->param('page');

    my $user = $self->user();
    if ((defined $self->param('pageSize')) and $user) {
        $model->setPageSize($user, $self->param('pageSize'));
    }

    my $editId;
    if ($action eq 'clone') {
        $editId = $self->param('id');
    } else {
        $editId = $self->param('editid');
    }

    my @params;
    push(@params, 'dataTable' => $model->table());
    push(@params, 'model' => $model);
    push(@params, 'action' => $action);
    push(@params, 'editid' => $editId);
    push(@params, 'hasChanged' => $global->unsaved());
    push(@params, 'filter' => $filter);
    push(@params, 'page' => $page);
    push(@params, 'user' => $user);

    return \@params;
}

sub _setJSONSuccess
{
    my ($self, $model) = @_;
    if (not exists $self->{json}) {
        $self->{json} = {};
    }

    $self->{json}->{success} = 1;
    $self->{json}->{messageClass} = $model->messageClass();
    my $msg = $model->popMessage();
    if ($msg) {
        $self->{json}->{message} = $msg;
    }
}

sub editAction
{
    my ($self) = @_;

    my $isForm    = $self->param('form');
    my $editField = $self->param('editfield');
    if (not $editField) {
        $self->{json} = { success => 0 };
    }

    my %params = $self->getParams();
    my $id = $self->editField(%params);
    if (not $editField)  {
        my $model  = $self->{'tableModel'};
        $self->_setJSONSuccess($model);
        if ($isForm) {
            return;
        }

        my $filter = $self->unsafeParam('filter');
        my $page   = $self->param('page');
        my $row    = $model->row($id);

        $self->{json}->{changed} = {
            $id => $self->_htmlForRow($model, $row, $filter, $page)
        };
        return;
    }
}

sub addAction
{
    my ($self, %params) = @_;

    $self->{json}->{success} = 0;

    my $rowId = $self->addRow();

    my $model  = $self->{'tableModel'};
    $self->_setJSONSuccess($model);

    if ($model->size() == 1) {
        # this was the first added row, reload all the table
        $self->{json}->{reload} = $self->_htmlForRefreshTable();
        $self->{json}->{highlightRowAfterReload} = $rowId;
        return;
    }

    # this calculations assume than only one row is added
    my $nAdded = 1;
    my $filter = $self->unsafeParam('filter');
    my $page   = $self->param('page');
    my $pageSize = $self->_pageSize();
    my @ids    = @{ $self->_modelIds($model, $filter) };
    my $lastIdPosition = @ids -1;

    my $beginPrinted = $page*$pageSize;
    my $endPrinted   = $beginPrinted + $pageSize -1;
    if ($endPrinted > $lastIdPosition) {
        $endPrinted = $lastIdPosition;
    }

    my $idPosition = undef;
    for (my $i = 0; $i < @ids; $i++) {
        if ($ids[$i] eq $rowId) {
            $idPosition = $i;
            last;
        }
    }
    if (not defined $idPosition) {
        EBox::warn("Cannot find table position for new row $rowId");
        return;
    } elsif (($idPosition < $beginPrinted) or ($idPosition > $endPrinted))  {
        # row is not shown in the actual page, go to its page
        my $newPage = floor($idPosition/$pageSize);
        $self->{json}->{reload}  = $self->_htmlForRefreshTable($newPage);
        return;
    }

    my $relativePosition;
    if ($idPosition == 0) {
        $relativePosition = 'prepend';
    } else {
        $relativePosition = $ids[$idPosition-1];
    }
    my $nPages =  ceil(scalar(@ids)/$pageSize);
    my $needSpace;
    if (($page + 1) == $nPages) {
        $needSpace = $endPrinted >= ($page+1)*$pageSize;
    } else {
        $needSpace = 1;
    }

    my $row     = $model->row($rowId);
    my $rowHtml = $self->_htmlForRow($model, $row, $filter, $page);
    $self->{json}->{added} = [ { position => $relativePosition, row => $rowHtml } ];

    if ($needSpace) {
        # remove last row since it would not been seen, this assummes that only
        # one row is added at the time
        $self->{json}->{removed} = [ $ids[$endPrinted] ];
    }

    my $befNPages =  ceil((@ids - $nAdded)/$pageSize);
    if ($nPages != $befNPages) {
        $self->{json}->{paginationChanges} = {
            page => $page,
            nPages => $nPages,
            pageNumbersText => $model->pageNumbersText($page, $nPages),
        };
    }
}

sub delAction
{
    my ($self) = @_;
    my $model  = $self->{'tableModel'};
    $self->{json} = { success => 0 };

    my $rowId;
    try {
        $rowId = $self->removeRow();
    } catch (EBox::Exceptions::DataInUse $e) {
        $self->{json}->{success} = 1;
        $self->{json}->{changeRowForm} = $self->_htmlForDataInUse(
            $model->table()->{actions}->{del},
            "$e",
           );
        return;
    };

    $self->_setJSONSuccess($model);

    # With the current UI is assumed that the delAction is done in the same page
    # that is shown

    my $filter = $self->unsafeParam('filter');
    my @ids    = @{ $self->_modelIds($model, $filter) };

    if (@ids == 0) {
        # no rows left in the table, reload
        $self->{json}->{reload} = $self->_htmlForRefreshTable();
        return;
    }

    my $page   = $self->param('page');
    my $pageSize = $self->_pageSize();
    my $nPages       = ceil(@ids/$pageSize);
    my $nPagesBefore = ceil((@ids+1)/$pageSize);
    my $pageChange   = ($nPages != $nPagesBefore);
    if ($pageChange and ($page+1 >= $nPagesBefore)) {
        # removed last page
        my $newPage = $page > 0 ? $page - 1 : 0;
        $self->{json}->{reload} = $self->_htmlForRefreshTable($newPage);
        $self->{json}->{success} = 1;
        return;
    }

    if ($pageChange) {
        $self->{json}->{paginationChanges} = {
            page => $page,
            nPages => $nPages,
            pageNumbersText => $model->pageNumbersText($page, $nPages),
        };
    }

    if (($page+1) < $nPagesBefore) {
        # no last page we should add new row to the table to replace the removed one
        my $positionToAdd = ($pageSize -1) + $page*$pageSize;
        my $idToAdd = $ids[$positionToAdd];
        my $addAfter = 'append';
        my $row    = $model->row($idToAdd);
        my $rowHtml = $self->_htmlForRow($model, $row, $filter, $page);
        $self->{json}->{added} = [ { position => $addAfter, row => $rowHtml } ];
    }

    $self->{json}->{removed} = [ $rowId ];
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
    my $pageSize = $self->_pageSize();
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
    if ($self->{json}) {
        $self->_setJSONSuccess($self->{'tableModel'});
    }
}

sub cloneAction
{
    my ($self) = @_;
    $self->refreshTable();
}

sub checkAllAction
{
    my ($self) = @_;
    $self->{json}->{success} = 0;
    my $value = $self->setAllChecks();
    $self->{json} = {
        success => 1,
        checkAllValue => $value
   };
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
    try {
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
            success => 1,
            wantDialog => $msg ? 1 : 0,
            message => $msg,
            title => $title
           };
    } catch ($ex) {
        $self->{json} = {
            success => 0,
            error => "$ex",
        };
    }
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
    my ($self) = @_;
    $self->_requireParam('action');
    my $action = $self->param('action');
    $self->{'action'} = $action;

    my $model = $self->{'tableModel'};

    my $directory = $self->param('directory');
    if ($directory) {
        $model->setDirectory($directory);
    }

    my $actionSub = $action . 'Action';
    try {
        if ($self->can($actionSub)) {
            $self->$actionSub(
                model => $model,
                directory => $directory,
                
           );
        } elsif ($model->customActions($action, $self->unsafeParam('id'))) {
            $self->customAction($action);
            $self->refreshTable()
        } else {
            throw EBox::Exceptions::Internal("Action '$action' not supported");
        }
    } catch(EBox::Exceptions::External $ex) {
        $ex->throw();
    } catch(EBox::Exceptions::Internal $ex) {
        $self->{json}->{error} = $self->_htmlForUnexpectedError($ex);
    } catch ($ex) {
        $self->{json}->{error} = $ex;
    }
}

sub _redirect
{
    my $self = shift;

    my $model = $self->{'tableModel'};

    return undef unless (defined($model));

    return $model->popRedirection();
}

# TODO: Move this function to the proper place
sub _printRedirect
{
    my ($self) = @_;
    my $url = $self->_redirect();
    return unless (defined($url));
    print qq{<script type="text/javascript">\$(document).ready(function(){ window.location.replace('$url'); });</script>};
}

sub _print
{
    my ($self) = @_;
    $self->SUPER::_print();
    unless ($self->{json}) {
        $self->_printRedirect;
    }
}

sub JSONReply
{
    my ($self, $json) = @_;
    # json return  should not put messages in the model object
    $self->{tableModel}->setMessage('');

    my $redirect = $self->_redirect();
    if ($redirect) {
        $json->{redirect} = $redirect;
    }

    return $self->SUPER::JSONReply($json);
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
    my ($self, $model, $row, $filter, $page) = @_;
    my $table = $model->table();

    my $html;
    my @params = (
        model => $model,
        row   => $row
   );

    push @params, (movable => $model->movableRows($filter));
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

    my $table = $model->table();

    my @params = (
        model  => $model,
        action => $action,
        user => $self->user(),

        editid => $editId,
        filter => $filter,
        page   => $page,
        tpages => $tpages,
        presetParams  => $presetParams,

        printableRowName => $model->printableRowName
    );

    my $html;
    $html = EBox::Html::makeHtml('/ajax/changeRowForm.mas', @params);

    return $html;
}


sub _htmlForDataInUse
{
    my ($self, $url, $msg) = @_;
    my $params = $self->paramsAsHash;
    return EBox::Html::makeHtml('/dataInUse.mas',
                                warning => $msg,
                                url     => $url,
                                params  => $params,
                                ajax    => 1,
                               );
}

sub _htmlForUnexpectedError
{
    my ($self, $ex) = @_;
    my $trace = $ex->trace();
    EBox::TraceStorable::storeTrace($trace, $self->request()->env());
    return $trace->redirect_html();
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
