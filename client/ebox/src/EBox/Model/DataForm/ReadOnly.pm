# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::Model::DataForm::ReadOnly
#
#       An specialized model from <EBox::Model::DataForm> which
#       only shows information in a form schema
#

package EBox::Model::DataForm::ReadOnly;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox uses
use EBox::Exceptions::Internal;
use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#      Create a new <EBox::Model::DataForm::ReadOnly> model instance
#
# Parameters:
#
#       gconfmodule - <EBox::GConfModule> the GConf eBox module which
#       gives the environment where to store data
#
#       directory - String the subdirectory within the environment
#       where the data will be stored
#
#       domain    - String the Gettext domain
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);

    bless ( $self, $class );

    return $self;

}

# Method: setRow
#
#      It has non sense in a read only form
#
# Overrides:
#
#      <EBox::Model::DataForm::setRow>
#
# Exceptions:
#
#      <EBox::Exceptions::Internal> - thrown since it is not possible
#      to set rows to a read only row
#
sub setRow
{
    throw EBox::Exceptions::Internal('It is not possible to set a row to ' .
                                     'an read only form');

}

# Method: setTypedRow
#
#      It has non sense in a read only form
#
# Overrides:
#
#      <EBox::Model::DataForm::setTypedRow>
#
# Exceptions:
#
#      <EBox::Exceptions::Internal> - thrown since it is not possible
#      to set rows to a read only row
#
sub setTypedRow
{
    throw EBox::Exceptions::Internal('It is not possible to set a row to ' .
                                     'an read only form');

}

# Method: row
#
#     Return the row.
#
# Overrides:
#
#     <EBox::Model::DataForm::row>
#
sub row
{

    my ($self) = @_;

    unless ( $self->{readOnlyed} ) {
        # Set every field as non-editable
        foreach my $fieldName (@{$self->fields()}) {
            my $field = $self->fieldHeader($fieldName);
            $field->{editable} = 0;
        }
        $self->{readOnlyed} = 1;
    }

    $self->{content} = $self->_content();

    if ( defined ( $self->{content} )) {
        my $types = $self->_fillTypes($self->{content});
        my %printableValueHash = map { $_->fieldName() => $_->printableValue() }
          values (%{$types});
        my @values = values (%{$types});
        return { values => \@values ,
                 valueHash => $types,
                 plainValueHash => $self->{content},
                 printableValueHash => \%printableValueHash,
               };
    } else {
        # Call SUPER::_row
        return $self->_row();
    }

}

# Group: Class methods

# Method: Viewer
#
# Overrides:
#
#     <EBox::Model::DataForm::Viewer>
#
sub Viewer
{

    return '/readOnlyForm.mas';

}

# Group: Protected methods

# Method: _content
#
#     This method is intended to be overridden by subclasses to return
#     the data acquired using the programming logic from wherever it
#     is needed.
#
#     It is predominant against default values from the model
#     description.
#
#     Default return value: undef
#
# Returns:
#
#     hash ref - the pair (key, value) where the key is the field name
#     from the model description using
#     <EBox::Model::DataTable::_table> and the value is the same used
#     when creating a type with a default value or setting or updating
#     using autoload methods. Check _setValue method from every
#     <EBox::Types> class for more information
#
sub _content
{

    return undef;

}

1;
