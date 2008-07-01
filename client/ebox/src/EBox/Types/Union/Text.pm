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

# Class: EBox::Types::Union::Text
#
#       This type is a specialized version of text to be used at
#       <EBox::Types::Union> type. Its meaning is the option which it
#       is left when the remainder options are not selected.
#
#       For example, a type representing a source as an union of an
#       object or an IP address can be as well represented as any as a
#       value determining that you are selected the whole selection
#       space.
#

package EBox::Types::Union::Text;

use strict;
use warnings;

use base 'EBox::Types::Text';

use EBox::Exceptions::NotImplemented;

# Group: Public methods

# Constructor: new
#
#       The constructor for the type
#
# Returns:
#
#       <EBox::Types::Union::Text> - the union text recently created
#       object
#
sub new
{
        my $class = shift;
        my %opts = @_;
        my $self = $class->SUPER::new(@_);
        $self->{'type'} = 'union/text';
        # If it is set to editable
        if ( $self->{editable} ) {
            EBox::warn('EBox::Types::Union::Text type cannot be editable ' .
                       'since it has no setter');
        }
        $self->{editable} = 0;

        bless($self, $class);
        return $self;
}

# Method: HTMLSetter
#
# Overrides:
#
#      <EBox::Types::Text::HTMLSetter>
#
sub HTMLSetter
  {

      return undef;

  }

# Method: value
#
# Overrides:
#
#       <EBox::Types::Abstract::value>
#
sub value
{
    my ($self) = @_;

    return $self->{'value'} if defined($self->{'value'});
    return $self->fieldName();
}

# Method: printableValue
#
# Overrides:
#
#       <EBox::Types::Abstract::printableValue>
#
sub printableValue
{
    my ($self) = @_;

    return $self->printableName();

}

# Protected Methods

# Method: _setMemValue
#
# Overrides:
#
#       <EBox::Types::Abstract::_setMemValue>
#
sub _setMemValue
  {

      my ($self, $params) = @_;

      $self->{'value'} = $self->fieldName();

  }

# Method: _restoreFromHash
#
# Overrides:
#
#       <EBox::Types::Abstract::_restoreFromHash>
#
sub _restoreFromHash
  {

      my ($self, $hash) = @_;

      $self->{'value'} = $self->fieldName();

  }

# Method: _storeInGConf
#
# Overrides:
#
#      <EBox::Types::Text::_storeInGConf>
#
sub _storeInGConf
  {
      my ($self, $gconfmod, $key) = @_;

      # Store nothing in GConf since it is already written as printableName
      return;

  }

# Method: _paramIsValid
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsValid>
#
sub _paramIsValid
{

    return 1;

}

# Method: _paramIsSet
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsSet>
#
sub _paramIsSet
  {

      return 1;

  }

# Method: _setValue
#
# Overrides:
#
#       <EBox::Types::Abstract::_setValue>
#
sub _setValue
{
    my ($self) = @_;

    $self->_setMemValue();

}

1;
