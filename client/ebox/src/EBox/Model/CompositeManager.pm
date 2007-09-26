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

# Class: EBox::Model::CompositeManager
#
#   This class is used to coordinate all the available composite
#   models along eBox. It allows us to have a centralized place where
#   all composite models are instanced.
#

# FIXME: Not just index by name but also by ebox module to allow name repetition

package EBox::Model::CompositeManager;

use strict;
use warnings;

# eBox uses
use EBox::Exceptions::DataNotFound;
use EBox::Global;

# Singleton variable
my $_instance = undef;

# Group: Public methods

# Method: Instance
#
#     Get the singleton instance of the composite manager.
#     *(Static method)*
#
# Returns:
#
#     <EBox::Model::CompositeManager> - the instance of the composite
#     manager
#
sub Instance
  {

      my ($class) = @_;

      unless ( defined ( $_instance )) {
          $_instance = $class->_new();
      }

      return $_instance;

  }

# Method: composite
#
#     Given a composite name it returns an instance of this composite
#
# Parameters:
#
#     composite - String the composite model's name
#
# Returns:
#
#     <EBox::Model::Composite> - the composite object
#
# Exceptions:
#
#     <EBox::Exceptions::DataNotFound> - thrown if the composite does
#     not exist
#
sub composite
  {

      my ($self, $compositeName) = @_;

      if ( exists $self->{composites}->{$compositeName}) {
          return $self->{composites}->{$compositeName};
      } else {
          throw EBox::Exceptions::DataNotFound( data  => 'composite',
                                                value => $compositeName,
                                              );
      }

  }

# Group: Private methods

# Constructor for the singleton variable
sub _new
  {

      my ($class) = @_;

      my $self = {};
      bless ($self, $class);

      $self->_setUpComposites();

      return $self;

  }

# Method: _setUpComposites
#
#     Fetch composites from all classes which implements the interface
#     <EBox::Model::CompositeProvider>
#
sub _setUpComposites
  {

      my ($self) = @_;

      my $global = EBox::Global->getInstance();

      my @modules = @{$global->modInstancesOfType('EBox::Model::CompositeProvider')};
      foreach my $module (@modules) {
          foreach my $composite (@{$module->composites()}) {
              $self->{composites}->{$composite->name()} = $composite;
          }
      }

  }

1;
