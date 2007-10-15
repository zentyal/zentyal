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

# Class: EBox::Model::CompositeProvider
#
#   Interface meant to be used for classes providing composites. That
#   is, those eBox modules which also have composites

package EBox::Model::CompositeProvider;
use base 'EBox::Model::ProviderBase';

use strict;
use warnings;

use constant TYPE => 'composite';

# eBox uses

sub composite
{
  my ($self, $name) = @_;
  return  $self->providedInstance(TYPE, $name);
}


# Method: composites
#
#   This method must be overridden in case of your module provides any
#   composite comprises models
#
# Returns:
#
#	array ref - containing instances of the composites
#
sub composites
{
  my ($self, $name) = @_;
  return  $self->providedInstances(TYPE, $name);
}


sub newCompositeInstance
{
  my ($self,  $class, @params) = @_;
  my $instance = $class->new(@params);

  return $instance;
}

# Method: compositeClasses
#
#
sub compositeClasses
{
  throw EBox::Exceptions::NotImplemented('compositeClasses');
}

1;
