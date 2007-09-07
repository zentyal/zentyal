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

# Class: EBox::Events::Model::ConfigurationComposite
#
#   This class is used to show
#   <EBox::Events::Model::ConfigureEventDataTable> and
#   <EBox::Events::Model::ConfigureDispatcherDataTable> inside a tab layout.
#

package EBox::Events::Model::ConfigurationComposite;

use base 'EBox::Model::Composite';

use strict;
use warnings;

## eBox uses
use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#         Constructor for the configuration tab composite
#
# Returns:
#
#       <EBox::Events::Model::ConfigurationComposite> - a
#       configuration tab composite
#
sub new
  {

      my ($class) = @_;

      my $self = $class->SUPER::new();

      return $self;

  }

# Group: Protected methods

# Method: _description
#
# Overrides:
#
#     <EBox::Model::Composite::_description>
#
sub _description
  {

      my $description =
        {
         components      => [
                             'ConfigureEventDataTable',
                             'ConfigureDispatcherDataTable',
                            ],
         layout          => 'tabbed',
         name            => 'ConfigurationComposite',
         printableName   => '',
         compositeDomain => 'Events',
        };

      return $description;

  }

1;
