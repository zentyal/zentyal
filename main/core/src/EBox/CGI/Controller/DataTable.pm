# Copyright (C) 2007 Warp Networks S.L
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


# Dependencies
use Error qw(:try);
use Clone;

sub new # (cgi=?)
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

    $params{'id'} = $self->param('id');
    my $filter  = $self->unsafeParam('filter');
    utf8::encode($filter);

    $params{'filter'} = $filter;

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
        my $element = $row->hashElements()->{$elementId};
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

sub moveRow
{
    my $self = shift;

    my $model = $self->{'tableModel'};

    $self->_requireParam('id');
    $self->_requireParam('dir');

    my $id = $self->param('id');
    my $dir = $self->param('dir');

    my $before = $model->_rowOrder($id);
    if ($dir eq 'up') {
        $model->moveUp($id);
    } else {
        $model->moveDown($id);
    }
    my $after = $model->_rowOrder($id);

    $self->_auditLog('move', $self->_getAuditId($id), $before, $after);
}

sub removeRow
{
    my $self = shift;

    my $model = $self->{'tableModel'};

    $self->_requireParam('id');
    my $id = $self->param('id');
    my $force = $self->param('force');

    $model->removeRow($id, $force);

    $self->_auditLog('del', $self->_getAuditId($id));
}

sub editField
{
    my $self = shift;

    my $model = $self->{'tableModel'};
    my %params = $self->getParams();
    my $force = $self->param('force');
    my $tableDesc = $model->table()->{'tableDescription'};

    my $id = $params{id};
    my $row = $model->row($id);
    my $auditId = $self->_getAuditId($id);

    # Store old and new values before setting the row for audit log
    my %changedValues;
    for my $field (@{$tableDesc} ) {
        my $fieldName = $field->fieldName();
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
    my $id = $self->param('id');
    my $field = $self->param('field');
    my $value = 0;
    if ($self->param('value')) {
        $value = 1;
    }

    my $currentRow = $model->row($id);
    my $oldValue = $currentRow->valueByName($field);
    my $element = $currentRow->elementByName($field);
    $element->setValue($value);
    $model->setTypedRow( $id, { $field => $element},
                        force => 1,
                        readOnly => 0);
    $model->popMessage();
    my $global = EBox::Global->getInstance();
    # XXX Factor this class to be able to print 'application/json'
    #     and 'text/html' headers. This way we could just return
    #     a json object { changes_menu: true } and get it evaled
    #     using prototype. That's the right way :)
    if ($global->unsaved()) {
        $self->_responseToEnableChangesMenuElement();
    }

    my $auditId = $self->_getAuditId($id);
    $self->_auditLog('set', "$id/$field", $value, $oldValue);
}

# prints a HTML response to enable the 'Save changes' web element
# don't p[ritn any other HTML if you use this
sub _responseToEnableChangesMenuElement
{
    my ($self) = @_;
    $self->_header();
    print '$("changes_menu").className = "changed"';
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

# Method to refresh the table by calling rows method
sub refreshTable
{
    my $self = shift;

    my $model = $self->{'tableModel'};
    my $global = EBox::Global->getInstance();

    my $filter = $self->unsafeParam('filter');
    utf8::encode($filter);

    my $page = $self->param('page');
    my $pageSize = $self->param('pageSize');
    if ( defined ( $pageSize )) {
        $model->setPageSize($pageSize);
    }
#    my $rows = $model->rows($filter, $page);
#    my $tpages = $model->pages($filter);
    my $rows = undef;
    my $tpages = 1000;
    my @params;
    push(@params, 'data' => $rows);
    push(@params, 'dataTable' => $model->table());
    push(@params, 'model' => $model);
    push(@params, 'action' => $self->{'action'});
    push(@params, 'editid' => $self->param('editid'));
    push(@params, 'hasChanged' => $global->unsaved());
    push(@params, 'filter' => $filter);
    push(@params, 'page' => $page);
    push(@params, 'tpages' => $tpages);

    $self->{'params'} = \@params;
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

    if ($action eq 'edit') {

        $self->editField();
        $self->refreshTable();

    } elsif ($action eq 'add') {
        my $rowId = $self->addRow();
        if ($json) {
            $self->{json}->{rowId} = $rowId;
            $self->{json}->{directory} = $directory;
            $self->{json}->{success} = 1;
        } else {
            $self->refreshTable();
        }
    } elsif ($action eq 'del') {

        $self->removeRow();
        $self->refreshTable();

    } elsif ($action eq 'move') {

        $self->moveRow();
        $self->refreshTable();

    } elsif ($action eq 'changeAdd') {

        $self->refreshTable();

    } elsif ($action eq 'changeList') {

        $self->refreshTable();

    } elsif ($action eq 'changeEdit') {

        $self->refreshTable();

    } elsif ($action eq 'view') {
        # This action will show the whole table (including the
        # table header similarly View Base CGI but inheriting
        # from ClientRawBase instead of ClientBase
        $self->{template} = $model->Viewer();
        $self->refreshTable();
    } elsif ($action eq 'editBoolean') {
        delete $self->{template};
        $self->editBoolean();
    } elsif ($model->customActions($action, $self->param('id'))) {
        $self->customAction($action);
        $self->refreshTable();
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

1;
