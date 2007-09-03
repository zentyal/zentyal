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

#   Class: EBox::Types::Link
#
#       This class represents a type which contains a hyperlink which
#       it will be used to set the content of a model field.
#
#       This is very useful when <EBox::Types::HasMany> is not
#       sufficient. For example, in order to configurate something
#       which requires the configuration of a whole eBox module, you
#       can advise the user setting this link so that he visits this.
#
package EBox::Types::Link;

use strict;
use warnings;

use base 'EBox::Types::Text';

# eBox uses
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::NotImplemented;
use EBox::Gettext;
use EBox::Validate;

# Group: Public methods

# Constructor: new
#
#      Create the type
#
# Returns:
#
#      <EBox::Types::Link> - the newly created type
#
sub new
  {

      my $class = shift;

      my %opts = @_;

      unless (exists $opts{'HTMLViewer'}) {
          $opts{'HTMLViewer'} ='/ajax/viewer/hasManyViewer.mas';
      }
      
      $opts{'type'}     = 'link';
      $opts{'editable'} = 0;
      $opts{'optional'} = 1;

      my $self = $class->SUPER::new(%opts);

      bless ( $self, $class );
      return $self;

  }


# Method: linkToView
#
#     Alias to <EBox::Types::Link::value> method to be used by the
#     hasManyViewer
#
# Returns:
#
#     String - the relative path to the eBox template
#
sub linkToView
  {

      my ($self) = @_;

      return $self->value();

  }

# Group: Protected methods

# Method: _paramIsValid
#
#     Check if the params has a correct link
#
# Overrides:
#
#    <EBox::Types::Abstract::_paramIsValid>
#
# Parameters:
#
#     params - the HTTP parameters with contained the type
#
# Returns:
#
#     true - if the parameter is a correct link address
#
# Exceptions:
#
#     <EBox::Exceptions::InvalidData> - throw if it's not a correct
#                                       link
#
sub _paramIsValid
  {

      my ($self, $params) = @_;

      my $value = $params->{$self->fieldName()};

      if ( defined ( $value )) {
          EBox::Validate::checkFilePath($value,
                                        $self->printableName());
      }

      return 1;

  }


1;
