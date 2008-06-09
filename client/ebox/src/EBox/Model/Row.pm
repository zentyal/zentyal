# Copyright (C) 2008 Warp Networks S.L.
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
#               - 'readOnly' => Boolean indicating if the row is readOnly or not
#       - 'values' => array ref containing objects
#               implementing <EBox::Types::Abstract> interface
#       - 'valueHash' => hash ref containing the same objects as
#          'values' but indexed by 'fieldName'
#
#       - 'plainValueHash' => hash ref containing the fields and their
#          value
#
#       - 'printableValueHash' => hash ref containing the fields and
#          their printable value

package EBox::Model::Row;


use strict;
use warnings;

# eBox uses
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;

use Error qw(:try);


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
#   gconfmodule - gconfmodule
#
# Overrides:
#
#     <EBox::Model::DataTable::new>
#
# Returns:
#
#     <EBox::Samba::Model::SambaShares> - the newly created object
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

    unless (exists $opts{gconfmodule}) {
        throw EBox::Exceptions::MissingArgument('gconfmodule');
    }
    $self->{'gconfmodule'} = $opts{gconfmodule};


    bless ( $self, $class);

    return $self;

}

# Group: Public methods

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

# Method: dir
#
#   GConf directory
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

# Method: GConfModule
#
#   Return the GConf module this row is stored in
#
# Returns:
#
#   A class implementing <EBox::GConfModule>
#
#
sub GConfModule
{
    my ($self) = @_;

    return $self->{gconfmodule};
}



# Method: addElement
#
#   Add an element to the row
#
# Parameters:
#
#   element - A class implementing <EBox::Type::Abstract> intterface
#
#
sub addElement
{
    my ($self, $element) = @_;

    unless (defined($element) and $element->isa('EBox::Types::Abstract')) {
        throw EBox::Exceptions::Internal('element is not a valid type');
    }

    my $dir = $self->dir();
    my $id = $self->id();

    # TODO Rework the union select options thing
    #      this code just sucks. Modify Types to do something
    #      nicer 
    if ($element->type() eq 'union') {
        # FIXME: Check if we can avoid this
        $self->{'plainValueHash'}->{$element->selectedType} = $element->value();
        $self->{'printableValueHash'}->{$element->selectedType} =
            $element->printableValue();
    }

    if ($element->type eq 'hasMany') {
        my $fieldName = $element->fieldName();
        $element->setDirectory("$dir/$id/$fieldName");
    }
    
    push (@{$self->{'values'}}, $element);
    
    $self->{'valueHash'}->{$element->fieldName()} = $element;
    $self->{'plainValueHash'}->{$element->fieldName()} = $element->value();
    $self->{'plainValueHash'}->{'id'} = $id;
    $self->{'printableValueHash'}->{$element->fieldName()} = 
        $element->printableValue();
    $self->{'printableValueHash'}->{'id'} = $id;

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
#   <EBox::Exceptions::DataNotFound> if the element does not exist
#
sub elementByName 
{
    my ($self, $element) = @_;

    unless (exists $self->{valueHash}->{$element}) {
        throw EBox::Exceptions::DataNotFound( data => 'element',
                                             value => $element);
    }

    return $self->{valueHash}->{$element};
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

    unless (($index + 1) > $self->size() ) {
        throw EBox::Exceptions::DataNotFound( data => 'index',
                                             value => $index);
    }

    return @{$self->{'values'}}[$index];
}

# Method: size
#
#   Return the numbe of elements of this row
#
# Return:
#
#   size - integer
#
#
sub size
{
    my ($self) = @_;

    unless (exists $self->{'values'}) {
        return 0;
    }

    return scalar(@{$self->{'values'}});
}




1;
