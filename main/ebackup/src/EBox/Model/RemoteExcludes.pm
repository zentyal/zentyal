# Copyright (C) 2009-2012 Zentyal S.L.
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


package EBox::EBackup::Model::RemoteExcludes;

# Class: EBox::EBackup::Model::RemoteExcludes
#
#
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Text;
use EBox::Validate;
use EBox::EBackup::Subscribed;
use EBox::Exceptions::NotConnected;
use EBox::FileSystem;
use Error qw(:try);
use String::ShellQuote;

use constant DEFAULT_EXCLUDES => ('/dev', '/proc', '/sys', '/mnt', '/media', '/tmp',
                                  '/var/spool', '/var/cache', '/var/tmp');

# Group: Public methods

# Constructor: new
#
#       Create the new Hosts model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::EBackup::Model::Hosts> - the recently created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{

    my @tableHeader = (
        new EBox::Types::Select(
            fieldName     => 'type',
            printableName => __('Type'),
            editable      => 1,
            populate      => \&_types,
        ),
        new EBox::Types::Text(
            fieldName     => 'target',
            printableName => __('Exclude or Include'),
            size          => 30,
            unique        => 0,
            editable      => 1,
            allowUnsafeChars => 1,
        ),
       new EBox::Types::Boolean (
            fieldName => 'system',
            hidden => 1,
            defaultValue => 0,
                                ),
    );

    my $dataTable =
    {
        tableName          => 'RemoteExcludes',
        printableTableName => __('Includes and Excludes'),
        printableRowName   => __('exclude or include'),
        rowUnique          => 1,
        defaultActions     => [ 'add', 'del', 'editField', 'changeView', 'move' ],
        order              => 1,
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        modelDomain        => 'EBackup',
        defaultEnabledValue => 1,
        insertPosition      => 'front',
        help => __(
'A file or directory is included or excluded according the first match. A directory match is applied to all it contents. Files not explicitly excluded or included are included'
           ),
    };

    return $dataTable;

}

# Group: Private methods

sub _types
{
    return [
        {
            value => 'exclude_path',
            printableValue => __('Exclude path')
        },
        {
            value => 'exclude_regexp',
            printableValue => __('Exclude by regular expression')
        },
        {
            value => 'include_path',
            printableValue => __('Include Path')
        },
    ];
}

sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    my $values = $self->_actualValues($changedFields, $allFields);
    my $id = $values->{type}->row()->id();
    my $type   = $values->{type}->value();
    my $target = $values->{target}->value();

    my $checkMethod = "_validate_" . $type;
    $self->$checkMethod($target);

    my $ebackup = $self->{gconfmodule};
    my $prefix = $ebackup->backupDomainsFileSelectionsRowPrefix(). '_';
    if ($id =~ m/^$prefix/) {
        # this row cannot be edited and we dont shoudl check their addition
        return;
    }

    if ($action eq 'add') {
        $self->_validateCoherence(action => $action,  type => $type, target => $target);
    } elsif ($action eq 'update') {
        $self->_validateCoherence(action => $action, id => $id, type => $type, target => $target);
    }
}

# Method: validateSwapPos
#
#  Validate swap position between rows
#
# Parameters:
#
#   action - action ('moveUp', 'moveDown')
#   id      - id of the row upon is done the action
#   swapA   - one of the positions to swap
#   swapB   - the other position to swap
sub validateSwapPos
{
    my ($self, $action, $id, $swapA, $swapB) = @_;
    $self->_validateCoherence(action => 'swap', swapA => $swapA, swapB => $swapB);
}


# Method: validateRemoveRow
#
#  Validate row removal
#
# Parameters:
#
#   id      -  id of the reow to remove
sub validateRemoveRow
{
    my ($self, $id) = @_;
    $self->_validateCoherence(action => 'remove', id => $id);
}

sub _pathsListWithModifications
{
    my ($self, %args) = @_;
    my $action = $args{action};
    my @pathsList = @{ $self->_ids() }; # this is called inside syncRows

    if ($action  eq 'add') {
        unshift @pathsList, {
            type => $args{type},
            target => $args{target},
           };
    } elsif ($action eq 'update') {
        my $id = $args{id};
        my $found = undef;
        foreach my $pathId (@pathsList) {
            if ($pathId eq $id) {
                $pathId = {
                    type => $args{type},
                    target => $args{target},
                   };
                $found = 1;
                last;
            }

        }
        if (not $found) {
            throw EBox::Exceptions::Internal("Id not found: $id");
        }

    } elsif ($action eq 'swap') {
        my $swapA = $args{swapA};
        my $swapB = $args{swapB};
        my $swapAValue  = $pathsList[$swapA];
        $pathsList[$swapA] = $pathsList[$swapB];
        $pathsList[$swapB] = $swapAValue;
    } elsif ($action eq 'remove') {
        my $id = $args{id};
        @pathsList = grep {
            $_ ne $id
        } @pathsList;

    } else {
        throw EBox::Exceptions::Internal("Invalid action: $action");
    }

    return \@pathsList;
}

sub _backupDomainsIncludes
{
    my ($self) = @_;
    my @backupDomainsIncludes = map {
        if ($_->{type} eq 'include') {
            $_->{value};
        } else {
            ();
        }
    } @{ $self->{gconfmodule}->modulesBackupDomainsFileSelections() };

    return \@backupDomainsIncludes;
}

sub _validateCoherence
{
    my ($self, %args) = @_;

    my @backupDomainsIncludes = @{ $self->_backupDomainsIncludes() };
    if (not @backupDomainsIncludes) {
        return;
    }
    my %domainIncludes = map {
        $_ => $_
    } @backupDomainsIncludes;

    my @pathsList = @{ $self->_pathsListWithModifications(%args) };
    foreach my $path (@pathsList) {
        my ($type, $target);
        if ((ref $path) eq 'HASH') {
            $type = $path->{type};
            $target = $path->{target};
        } else {
            my $row = $self->row($path);
            $target = $row->valueByName('target');
            $type = $row->valueByName('type');
        }

        my $checkSubdirectory;
        if ($type eq 'exclude_path') {
            $checkSubdirectory = 1;
        } elsif ($type eq 'exclude_regexp') {
            $checkSubdirectory = EBox::Validate::checkAbsoluteFilePath($target);
        }

        foreach my $include (keys %domainIncludes) {
            if ($type eq 'exclude_regexp') {
                if ($include =~ m/$target/) {
                     throw EBox::Exceptions::External(
                         __x(q|Cannot {action} because the path '{path}', added by backup domains, would be excluded by the regular expression|,
                              action => _actionPrintableName($args{action}),
                              path => $include)
                        );
                 }
            } elsif (EBox::FileSystem::isSubdir($include, $target)) {
                if ($type eq 'include_path') {
                    # remove included paths by the target
                    delete $domainIncludes{$include};

                } else {
                    throw EBox::Exceptions::External(
                        __x(q|Cannot {action} because the path '{path}', added by backup domains, would be excluded|,
                            action => _actionPrintableName($args{action}),
                            path => $include
                               )
                       );
                }
            }

            if ($checkSubdirectory and EBox::FileSystem::isSubdir($target, $include)) {
                throw EBox::Exceptions::External(
                        __x(q|Cannot {action} because a subdirectory of  '{path}', added by backup domains, would be excluded|,
                            action => _actionPrintableName($args{action}),
                            path => $include)
                );
            }
        } # en foreach my include

    } # end foreach my path
}


sub _actionPrintableName
{
    my ($action) = @_;
    if ($action eq 'add') {
        return __('add row');
    } elsif ($action eq 'update') {
        return __('edit row');
    } elsif ($action eq 'moveUp') {
        return __('move up row');
    } elsif ($action eq 'moveDown') {
        return __('move down row');
    } elsif ($action eq 'remove') {
        return __('remove down');
    } else {
        return $action;
    }
}

sub _validate_exclude_path
{
    my ($self, $target) = @_;
    EBox::Validate::checkAbsoluteFilePath($target,
                                          __('exclude path')
                                          );
}

sub _validate_exclude_regexp
{
    my ($self, $target) = @_;

    eval {
        my $regex = qr/$target/;
    } ;
    if ($@) {
        throw EBox::Exceptions::InvalidData(
                      data => __('exclude path regular expression'),
                      value => $target,
                      advice => __('Incorrect regular expression'),
                                           );
    }

}




sub _validate_include_path
{
    my ($self, $target) = @_;

    if ($target eq '/') {
        throw EBox::Exceptions::External(
q{'/' is a invalid value for includes. Files in '/' are included if they are not excluded first.}
           );
    }


    EBox::Validate::checkAbsoluteFilePath($target,
                                          __('include path')
                                          );
}




sub _actualValues
{
    my ($self,  $paramsRef, $allFieldsRef) = @_;
    my %actualValues = %{ $allFieldsRef };
    while (my ($key, $value) = each %{ $paramsRef }) {
        $actualValues{$key} = $value;
    }

    return \%actualValues;
}

# Method: syncRows
#
#  Needed to show all backup domains provided by the modules
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentIds) = @_;

    my $ebackup  = $self->{'gconfmodule'};
    my $changed = 0;

    unless (@{$currentIds}) {
        # if there are no rows, we have to add them
        foreach my $exclude (DEFAULT_EXCLUDES) {
            $self->add(type => 'exclude_path', target => $exclude);
        }
        $changed = 1;
    }

    my $prefix = $ebackup->backupDomainsFileSelectionsRowPrefix(). '_';

    my %currentDsIds;
    foreach my $rowId (@{ $currentIds }) {
        if ($rowId =~ m/^$prefix/) {
            $currentDsIds{$rowId} = $rowId;
        }
    }

    my $drAddon = 0;
    try {
        $drAddon = EBox::EBackup::Subscribed->isSubscribed();
    } catch EBox::Exceptions::NotConnected with {
        # connection error so we don't know whether we are subscribed or not
        # we will supposse that if we have ids with DS prefix we are subscribed
        $drAddon = keys %currentDsIds > 0;
    };

    if (not $drAddon) {
        # no disaster recovery add-on, so we not add nothing and remove old added rows
        # if neccessary
        foreach my $id (keys %currentDsIds) {
            $self->removeRow($id);
            $changed = 1;
        }
        return $changed;
    }


    my @domainsSelections = @{ $ebackup->modulesBackupDomainsFileSelections() };
    # check if there are missing or superfluous rows
    my @toAdd;
    foreach my $domainSelection (@domainsSelections) {
        my $id = $domainSelection->{id};
        my $alreadyAdded = delete $currentDsIds{$id};
        if (not $alreadyAdded) {
            push @toAdd, $domainSelection;
        }
    }
    if (not @toAdd and (keys %currentDsIds == 0)) {
        return $changed;
    }

    # remove not longer needed rows
    foreach my $id (keys %currentDsIds) {
        $self->removeRow($id);
    }

    @toAdd = reverse @toAdd;
    foreach my $selection (@toAdd) {
        my $type;
        if ($selection->{type} eq 'include') {
            $type = 'include_path';
        } elsif ($selection->{type} eq 'exclude') {
            $type = 'exclude_path';
        } elsif ($selection->{type} eq 'exclude-regexp') {
            $type = 'exclude_regexp';
        }

        $self->addRow(
                      id => $selection->{id},
                      type => $type,
                      target => $selection->{value},
                      system  => 1,
                      readOnly => 1,
                      movable  => 1,
                     );
    }

    return 1;
}


# need to overload this to discriminate between user added path and system added paths
sub _checkRowIsUnique
{
    my ($self, $rowId, $row_ref) = @_;

    # we only care abotu the target field
    my $target = $row_ref->{target};
    my $rowSystem = $row_ref->{system}->value();
    if ($rowSystem) {
        # system rows are always added
        return;
    }


    # Call _ids instead of ids because of deep recursion
    foreach my $id (@{$self->_ids(1)}) {
        my $row = $self->row($id);
        next unless defined($row);

        # Compare if the row identifier is different
        next if ( defined($rowId) and $row->{'id'} eq $rowId);

        my $rowTarget = $row->elementByName('target');
        if ($target->isEqualTo($rowTarget)) {
            throw EBox::Exceptions::DataExists(
                                           'data'  => $target->printableName(),
                                           'value' => $target->value()
                                           );
        }


    }
}

# Check wether some file will be included in the backup or not
sub hasIncludes
{
    my ($self) = @_;

    my $ebackup  = $self->{'gconfmodule'};
    my $prefix =  $ebackup->backupDomainsFileSelectionsRowPrefix(). '_';
    my $prefixRe = qr/^$prefix/;

    foreach my $id (@{$self->ids()}) {
        if ($id =~ m/$prefixRe/) {
            # is a system row, skip
            next;
        }

        my $row = $self->row($id);
        my $type = $row->valueByName('type');
        if ($type eq 'include_path') {
            return 1;
        }

        my $target = $row->valueByName('target');
        if ($target eq '/') {
            # target could be a equivalent regex when the type is exclude_regex
            # but we will not manage this
            return 0;
        }
    }

    return 1; # by default '/' is included
}


sub fileSelectionArguments
{
    my ($self, %params) = @_;
    my $normalSelections = exists $params{normalSelections} ? $params{normalSelections} : 1;
    my $domainSelections = exists $params{domainSelections} ? $params{domainSelections} : 1;

    my $prefixRe;
    if (not $normalSelections or not $domainSelections) {
        my $ebackup = $self->{gconfmodule};
        my $prefix =  $ebackup->backupDomainsFileSelectionsRowPrefix(). '_';
        $prefixRe = qr/^$prefix/;
    }

    my $args = '';
    foreach my $id (@{ $self->ids() }) {
        if (not $normalSelections and (not $id =~ $prefixRe)) {
            next;
        } elsif (not $domainSelections and ($id =~ $prefixRe)) {
            next;
        }

        my $row = $self->row($id);
        my $type = $row->valueByName('type');
        if ($type eq 'exclude_path') {
            my $path = shell_quote($row->valueByName('target'));
            $args .= "--exclude=$path ";
        } elsif ($type eq 'include_path') {
            my $path = shell_quote($row->valueByName('target'));
            if ($path eq '/') {
                EBox::warn(
  q{Not neccesary to include '/' directory in ebackup. Ignoring}
                   );
                next;
            }
            $args .= "--include=$path ";
        } elsif ($type eq 'exclude_regexp') {
            my $regexp = shell_quote($row->valueByName('target'));
            $args .= "--exclude-regexp $regexp " ;
        }
    }

    return $args;
}

sub Viewer
{
    return '/ebackup/ajax/remoteExcludes.mas';
}

# reimplemetation to allow validation of moving rows using the method validateSwapPos
# if we like it we should move it to EBox::Model::DataTable

sub moveUp
{
    my ($self, $id) = @_;

    my %order = $self->_orderHash();

    my $pos = $order{$id};
    if ($pos == 0) {
        return;
    }

    $self->validateSwapPos('moveUp', $id, $pos, $pos -1);

    $self->_swapPos($pos, $pos - 1);

    $self->setMessage($self->message('moveUp'));
    $self->movedUpRowNotify($self->row($id));
    $self->_notifyModelManager('moveUp', $self->row($id));
    $self->_notifyCompositeManager('moveUp', $self->row($id));
}

sub moveDown
{
    my ($self, $id) = @_;

    my %order = $self->_orderHash();
    my $numOrder = keys %order;

    my $pos = $order{$id};
    if ($pos == $numOrder -1) {
        return;
    }

    $self->validateSwapPos('moveDown', $id, $pos, $pos + 1);

    $self->_swapPos($pos, $pos + 1);

    $self->setMessage($self->message('moveDown'));
    $self->movedDownRowNotify($self->row($id));
    $self->_notifyModelManager('moveDown', $self->row($id));
    $self->_notifyCompositeManager('moveDown', $self->row($id));
}


# reimplemetation to allow validation of removalopearation using the method validateRemoveRow
# if we like it we should move it to EBox::Model::DataTable
sub removeRow
{
    my ($self, $id, $force) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument(
                "Missing row identifier to remove")
    }

    $self->validateRemoveRow($id);
    return $self->SUPER::removeRow($id, $force)
}

1;
