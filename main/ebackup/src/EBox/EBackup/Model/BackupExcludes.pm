# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::EBackup::Model::BackupExcludes;

use base 'EBox::Model::DataTable';

# Class: EBox::EBackup::Model::BackupExcludes
#
#
#

use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Text;
use EBox::Validate;
use EBox::Exceptions::NotConnected;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::FileSystem;
use TryCatch;
use String::ShellQuote;

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
    );

    my $dataTable =
    {
        tableName          => 'BackupExcludes',
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
'A file or directory is included or excluded according the first match. A directory match is applied to all it contents. Anything that is not included is excluded by default.'
           ),
    };

    return $dataTable;

}

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
}


sub _actionPrintableName
{
    my ($action) = @_;
    if ($action eq 'add') {
        return __('add row');
    } elsif ($action eq 'update') {
        return __('edit row');
    } elsif ($action eq 'remove') {
        return __('remove row');
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

sub fileSelectionArguments
{
    my ($self) = @_;

    my $args = '';
    my $defaultExcludes = EBox::Config::configkey('ebackup_default_excludes');
    my @excludes = split (' ', $defaultExcludes);
    foreach my $exclude (@excludes) {
        $args .= "--exclude=$exclude ";
    }

    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        my $type = $row->valueByName('type');
        if ($type eq 'exclude_path') {
            my $path = shell_quote($row->valueByName('target'));
            $args .= "--exclude=$path ";
        } elsif ($type eq 'include_path') {
            my $path = shell_quote($row->valueByName('target'));
            $args .= "--include=$path ";
        } elsif ($type eq 'exclude_regexp') {
            my $regexp = shell_quote($row->valueByName('target'));
            $args .= "--exclude-regexp $regexp " ;
        }
    }

    $args .= "--exclude / ";

    return $args;
}

1;
