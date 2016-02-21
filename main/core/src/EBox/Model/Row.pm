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

# Class: EBox::Model::Row
#
#   This class represents a row.
#
#   TODO: #   Add more convenient methods
#
#   The preferred way to use this class is using its methods. Although for
#   backwards compatibility here is the internal representation of the row:
#
#   Hash reference containing:
#
#       - 'id' =>  row id
#       - 'order' => row order
#       - 'readOnly' => Boolean indicating if the row is readOnly or not
#       - 'disabled' => Boolean indicating if the row is disabled in the UI.
#                       Disabled and read only are orthogonal concepts.
#                       Read only means the row can not be modified, while
#                       disabled means the row exists, can be modified or
#                       deleted but it is ignored by the system.
#       - 'values' => array ref containing objects
#               implementing <EBox::Types::Abstract> interface
#       - 'valueHash' => hash ref containing the same objects as
#          'values' but indexed by 'fieldName'
#
use strict;
use warnings;

package EBox::Model::Row;

use EBox::Model::Manager;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidType;
use EBox::Exceptions::DataNotFound;

use TryCatch;

# Dependencies

# Group: Public methods

# Constructor: new
#
#     Create a row
#
# Parameters:
#
#   (NAMED)
#
#   dir - row's directory
#   confmodule - confmodule
#
#
# Returns:
#
#     <EBox::model::Row> - the newly created object
#     instance
#
sub new
{
    my ($class, %opts) = @_;

    my $self;
    unless (exists $opts{dir}) {
        throw EBox::Exceptions::MissingArgument('dir');
    }
    $self->{'dir'} = $opts{dir};

    unless (exists $opts{confmodule}) {
        throw EBox::Exceptions::MissingArgument('confmodule');
    }
    $self->{'confmodule'} = $opts{confmodule};
    $self->{'values'} = [];

    bless ($self, $class);

    return $self;
}

# Group: Public methods

# Method: model
#
#   model which this row belongs to
#
# Returns:
#
#   An instance of a class implementing <EBox::Model::DataTable>
#
sub model
{
    my ($self) = @_;

    return  $self->{'model'};
}

# Method: setModel
#
#   set the model
#
# Parameters:
#
#   (Positional)
#
#   model - An instance of a class implementing <EBox::Model::DataTable>
#
# Returns:
#
#   An instance of a class implementing <EBox::Model::DataTable>
#
sub setModel
{
    my ($self, $model) = @_;

    unless (defined($model)) {
        throw EBox::Exceptions::MissingArgument('model');
    }

    unless ($model->isa('EBox::Model::DataTable')) {
        throw EBox::Exceptions::InvalidType(arg => 'model',
                                            type => 'EBox::Model::DataTable' );
    }

    $self->{'model'} = $model;
}

# Method: id
#
#   row's id
#
# Returns:
#
#   string - containing id
#
#
sub id
{
    my ($self) = @_;

    return $self->{id};
}

# Method: setId
#
#   Set row id
#
# Returns:
#
#   string - containing id
#
#
sub setId
{
    my ($self, $id) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument('id');
    }

    $self->{id} = $id;
}

# Method: readOnly
#
#   row's readOnly
#
# Returns:
#
#   string - containing readOnly
#
#
sub readOnly
{
    my ($self) = @_;

    return $self->{readOnly};
}

# Method: setReadOnly
#
#   Set row readOnly
#
# Returns:
#
#   string - containing readOnly
#
#
sub setReadOnly
{
    my ($self, $readOnly) = @_;

    $self->{readOnly} = $readOnly;
}

# Method: disabled
#
#   Row disable
#
# Returns:
#
#   boolean - true if row is disabled, false otherwise
#
sub disabled
{
    my ($self) = @_;

    return $self->{disabled};
}

# Method: setDisabled
#
#   Set the row disabled flag
#
sub setDisabled
{
    my ($self, $disabled) = @_;

    unless (defined $disabled) {
        throw EBox::Exceptions::MissingArgument('disabled');
    }

    $self->{disabled} = $disabled;
}

# Method: dir
#
#   configuration directory
#
# Returns:
#
#   string - containing dir
#
#
sub dir
{
    my ($self) = @_;

    return $self->{dir};
}

# Method: parentRow
#
#   Return parent row if any. This methods makes sense when is used
#   by submodels
#
# Returns:
#
#   An instance of class implmenenting <EBox::Model::Row>
#   or undef if it has no parent
#
sub parentRow
{
    my ($self) = @_;

    my $model = $self->model();
    unless ($model) {
        return undef;
    }
    return $model->parentRow();
}

# Method: order
#
#   row's order
#
# Returns:
#
#   string - containing order
#
#
sub order
{
    my ($self) = @_;

    return $self->{order};
}

# Method: setOrder
#
#   Set row order
#
# Returns:
#
#   string - containing order
#
#
sub setOrder
{
    my ($self, $order) = @_;

    unless (defined($order)) {
        return;
    }

    $self->{order} = $order;
}

# Method: configModule
#
#   Return the GConf module this row is stored in
#
# Returns:
#
#   A class implementing <EBox::Module::Config>
#
#
sub configModule
{
    my ($self) = @_;

    return $self->{confmodule};
}

# Method: addElement
#
#   Add an element to the row
#
# Parameters:
#
#   element - A class implementing <EBox::Type::Abstract> interface
#
#
sub addElement
{
    my ($self, $element) = @_;

    unless (defined($element) and $element->isa('EBox::Types::Abstract')) {
        throw EBox::Exceptions::Internal('element is not a valid type');
    }

    my $fieldName = $element->fieldName();
    if (not $fieldName) {
        throw EBox::Exceptions::Internal('element has not field name or has a empty one');
    }

    if ($self->elementExists($fieldName)) {
        throw EBox::Exceptions::Internal(
           "Element $fieldName already is in the row"
                                        );
    }

    $element->setRow($self);
    $element->setModel($self->model());

    push (@{$self->{'values'}}, $element);
    $self->{'valueHash'}->{$fieldName} = $element;
}

# Method: elementExists
#
#   Check if a given element exists
#
# Parameters:
#
#   element - element's name
#
# Exceptions:
#
#   boolean - 1 or undef
#
sub elementExists
{
    my ($self, $element) = @_;

    unless ($element) {
        throw EBox::Exceptions::MissingArgument('element');
    }

    if (exists $self->{valueHash}->{$element}) {
        return 1;
    } else {
        # this is only for EBox::Types::Union selected subtype
        for my $value (@{$self->{values}}) {
            next unless  ($value->isa('EBox::Types::Union'));
            return 1 if ($value->selectedType() eq $element);
        }
    }

    return undef;
}

# Method: elementByName
#
#  Retreive an element from a row
#
# Parameters:
#
#   element - element's name
#
# Exceptions:
#
#   undef - if the element exists under a union type but it's not
#           the selected one
#   <EBox::Exceptions::DataNotFound> if the element does not exist
#
#
sub elementByName
{
    my ($self, $element) = @_;

    unless ($element) {
        throw EBox::Exceptions::MissingArgument('element');
    }

    if (exists $self->{valueHash}->{$element}) {
        return $self->{valueHash}->{$element};
    } else {
        for my $value (@{$self->{values}}) {
            next unless  ($value->isa('EBox::Types::Union'));
            if ($value->selectedType() eq $element) {
                return $value->subtype();
            }
            for my $type (@{$value->subtypes}) {
                return undef if ($type->fieldName() eq $element);
            }
        }
    }

    throw EBox::Exceptions::DataNotFound(data => 'element',
                                         value => $element);
}

# Method: elementByIndex
#
#  Retreive an element from a row  by index
#
# Parameters:
#
#   index - integer
#
# Exceptions:
#
#   <EBox::Exceptions::DataNotFound> if the element does not exist
#
sub elementByIndex
{
    my ($self, $index) = @_;

    unless (defined $index) {
        throw EBox::Exceptions::MissingArgument('index');
    }

    unless ($index < $self->size()) {
        throw EBox::Exceptions::DataNotFound(data => 'index',
                                             value => $index);
    }

    return @{$self->{'values'}}[$index];
}

# Method: elements
#
#   Return the elements contained in the row
#
# Returns:
#
#   array ref of <EBox::Types::Abstract>
#
sub elements
{
    my ($self) = @_;

    return $self->{'values'};
}

# Method: hashElements
#
#   Return the elements contained in the row
#   in a hash ref
#
# Returns:
#
#   hash ref of <EBox::Types::Abstract>
#
sub hashElements
{
    my ($self) = @_;

    return $self->{'valueHash'};
}

# Method: valueByName
#
#   Return the value of a given element.
#   This method will fecth the element and will
#   return element->value().
#
#   Element is a subclass of <EBox::Types::Abstract>
#
# Returns:
#
#   Whatever the given type returns
#
sub valueByName
{
    my ($self, $name) = @_;

    unless ($name) {
        throw EBox::Exceptions::MissingArgument('name');
    }

    my $element = $self->elementByName($name);

    unless ($element) {
        throw EBox::Exceptions::Internal("Element '$name' does not exist in row '$self->{dir}'");
    }

    return $element->value();
}

# Method: printableValueByName
#
#   Return the printableValue of a given element.
#   This method will fecth the element and will
#   return element->printableBalue().
#
#   Element is a subclass of <EBox::Types::Abstract>
#
#
# Returns:
#
#   Whatever the given type returns
#
sub printableValueByName
{
    my ($self,$name) = @_;

    unless ($name) {
        throw EBox::Exceptions::MissingArgument('name');
    }

    return $self->elementByName($name)->printableValue();
}

# Method: size
#
#   Return the numbe of elements of this row
#
# Return:
#
#   size - integer
#
sub size
{
    my ($self) = @_;

    unless (exists $self->{'values'}) {
        return 0;
    }

    return scalar(@{$self->{'values'}});
}

# Method: store
#
#   This method is used to synchronize the elements of a row with usually disk.
#
# Exceptions:
#
#   <EBox::Exceptions::Internal>
#
sub store
{
    my ($self) = @_;

    my $model = $self->model();

    unless (defined($model)) {
        throw EBox::Exceptions::Internal('Cannot store a row without a model');
    }

    $model->setTypedRow($self->id(),
                        $self->{'valueHash'},
                        readOnly => $self->readOnly(),
                        disabled => $self->disabled(),
                        force => 1);
}

# Method: storeElementByName
#
#   This method is used to synchronize a given element of a row with
#   usually disk.
#
#   Use this method if you just want to store one element
#
# Parameters:
#
#   element - element's name
#
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument> - thrown if element is missing
#
#   <EBox::Exceptions::Internal>
#
sub storeElementByName
{
    my ($self, $element) = @_;

    unless ($element) {
        throw EBox::Exceptions::MissingArgument('element');
    }

    my $model = $self->model();

    $model->setTypedRow($self->id(),
                        {$element => $self->elementByName($element)},
                        readOnly => $self->readOnly(),
                        disabled => $self->disabled(),
                        force => 1);
}

# Method: subModel
#
#   Return a submodel contained in hasMany type
#
# Parameters:
#
#   fieldName - string identifying a hasMany type
#
# Returns:
#
#   An instance of a child class of <EBox::Model::Component>
#
# Exceptions:
#
#   <EBox::Exceptions::DataNotFound> if the element does not exist
#   <EBox::Exceptions::MissingArgument>
#   <EBox::Exceptions::Internal>
#
sub subModel
{
    my ($self, $fieldName) = @_;

    unless ($fieldName) {
        throw EBox::Exceptions::MissingArgument('fieldName');
    }

    my $element = $self->elementByName($fieldName);
    unless ($element->isa('EBox::Types::HasMany')) {
        throw EBox::Exceptions::Internal("$fieldName is not a HasMany type");
    }

    my $model;
    try {
        $model = $element->foreignModelInstance();
    } catch (EBox::Exceptions::DataNotFound $e) {
        EBox::warn("Couldn't fetch foreign model: " . $element->foreignModel());
    }

    return $model;
}

# Method: matchFilter
#
#  Check if any of the printable values of the row matches a given filter
#
# Parameters:
#
#   filter - string containing the filter
#
# Returns:
#
#   boolean - true if it matches, false otherwise
#
sub matchFilter
{
    my ($self, $filter) = @_;
    unless ($filter) {
        throw EBox::Exceptions::MissingArgument('filter');
    }

    for my $value (@{$self->{values}}) {
        next if ($value->hidden() or $value->isa('EBox::Types::Link'));

        return 1 if ($value->printableValue() =~ /$filter/i);
    }

    return undef;
}

# Method: cloneSubModelsFrom
#
#  Auxiliary method for EBox::Model::DataTable to help it to clone the submodels
sub cloneSubModelsFrom
{
    my ($self, $otherRow) = @_;
    my @hasMany = grep { $_->isa('EBox::Types::HasMany') } @{$self->elements()};

    @hasMany or
        return;

    my $id = $self->id();
    my $otherId0 = $otherRow->id();

    foreach my $hasMany (@hasMany) {
        my $fieldName = $hasMany->fieldName();

        my $subModel   = $self->subModel($fieldName);
        my $subDir = $subModel->directory();

        my $otherSubModel = $otherRow->subModel($fieldName);
        my $otherSubDir = $otherSubModel->directory();

        $subModel->clone($otherSubDir, $subDir);
    }
}

sub isEqualTo
{
    my ($self, $other) = @_;

    if ($self->model()->contextName() ne $other->model()->contextName()) {
        # rows for different models are differents,  we assume
        # rows from different instances of the same model could be equal
        return 0;
    }

    if ($self->size() != $other->size()) {
        return 0;
    }

    my $myElements = $self->hashElements();
    my $otherElements = $other->hashElements();
    foreach my $myKey (keys %{$myElements}) {
        return 0 unless exists $otherElements->{$myKey};
        my $myElement = $myElements->{$myKey};
        my $otherElement = $otherElements->{$myKey};
        return 0 unless ($myElement->isEqualTo($otherElement));
    }

    return 1;
}

1;
