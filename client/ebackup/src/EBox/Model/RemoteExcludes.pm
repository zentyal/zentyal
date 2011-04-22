# Copyright (C) 2009-2010 eBox Technologies S.L.
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

use Error qw(:try);

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
    my $type   = $values->{type}->value();
    my $target = $values->{target}->value();

    my $checkMethod = "_validate_" . $type;
    $self->$checkMethod($target);

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
    # If the GConf module is readonly, return current rows
    if ( $ebackup->isReadOnly() ) {
        return undef;
    }

    my $prefix =  $ebackup->backupDomainsFileSelectionsRowPrefix(). '_';

    my @currentDsIds;
    foreach my $row (@{ $currentIds }) {
        if ($row =~ m/^$prefix/) {
            push @currentDsIds, $row;
        } else {
            last;
        }
    }

    my $drAddon = 0;
    try {
        $drAddon = EBox::EBackup::Subscribed->isSubscribed();
    } catch EBox::Exceptions::NotConnected with {
        # connection error so we don't know whether we are subscribed or not
        # we will supposse that if we have ids with DS prefix we are subscribed
        $drAddon = @currentDsIds > 0;
    };

    if (not $drAddon) {
        # no disaster recovery add-on, so we not add nothing and remove old added rows
        # if neccessary
        my $changed = undef;
        foreach my $id (@currentDsIds) {
            $self->removeRow($id);
            $changed = 1;
        }
        return $changed;
    }

    my @domainsSelections = @{ $ebackup->modulesBackupDomainsFileSelections() };
    if (@domainsSelections == @currentDsIds) {
        # check if there arent any change
        my $equal = 1;
        my $i = 0;
        while ($i < @domainsSelections) {
            if ($domainsSelections[$i]->{id} ne  $currentDsIds[$i]) {
                $equal = 0;
                last;
            }
        }
        if ($equal) {
            return undef;
        }
    }

    # changed, so to hedge to any order change we will remove all the old domain
    # backup related row and add new ones
    foreach my $id (@currentDsIds) {
        $self->removeRow($id);
    }

    foreach my $selection (@domainsSelections) {
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
                     );
    }

    my $modIsChanged =  EBox::Global->getInstance()->modIsChanged($ebackup->name());
    if (not $modIsChanged) {
        $ebackup->_saveConfig();
        EBox::Global->getInstance()->modRestarted($ebackup->name());
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
        # systme rows are always added
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

# we override this bz if we have read-only rows we want not to have user rows
# before them
# XXX duplicate phantom rows error!
sub _insertPos
{
    my ($self, $id, $pos) = @_;

    my $drAddon = 0;
    try {
        $drAddon = EBox::EBackup::Subscribed->isSubscribed();
    } catch EBox::Exceptions::NotConnected with {
        # connection error so we will play safe and assume we have it, this only
        # will cost a bit more time for the insertion
        $drAddon = 1;
    };

    if (not $drAddon) {
        # no disaster recovery add-on, so we havent nothing to change there
        return $self->SUPER::_insertPos($id, $pos);
    }

    my $ebackup  = $self->{'gconfmodule'};
    my $prefix =  $ebackup->backupDomainsFileSelectionsRowPrefix(). '_';
    my $prefixRe =~ qr/^$prefix/;
    if ($id =~ m/$prefixRe/) {
        # is a system row, nothing to do
        return $self->SUPER::_insertPos($id, $pos);
    }

    # assure that a user row is not added before a ssytem row
    my $newPos = $pos;
    my @order = @{$ebackup->get_list($self->{'order'})};
    foreach my $n (0 .. @order) {
        if ($n >= @order) {
            $newPos = $n;
            last;
        }
        if ($n < $pos) {
            next;
        }

        if ($order[$n] =~ m/$prefixRe/) {
            next;
        } else {
            $newPos = $n;
        }
    }

    my $ret = $self->SUPER::_insertPos($id, $newPos);
    return $ret;
}

# XXX fudge to avoid duplicate rows, this is not the ideal solution
sub ids
{
    my ($self, @args) = @_;
    my %seen;
    my @noDupIds;
    foreach my $id (@{ $self->SUPER::ids(@args) }) {
        if (exists $seen{$id}) {
            # duplicate!
            next;
        }
        push @noDupIds, $id;
        $seen{$id} = 1;
    }

    return \@noDupIds;
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

1;
