# Copyright (C) 2009 eBox Technologies S.L.
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
            unique        => 1,
            editable      => 1,
            allowUnsafeChars => 1,
        ),
    );

    my $dataTable =
    {
        tableName          => 'RemoteExcludes',
        printableTableName => __('Includes and Excludes'),
        printableRowName   => __('exclude or include'),
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
            printableValue => __('Exclude regexp')
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

1;
