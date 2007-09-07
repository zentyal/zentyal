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

# Class: EBox::Events::Model::EventsComposite
#
#   This class is used to manage the events module within a single
#   element whose components
#   are: <EBox::Events::Model::ConfigurationComposite> and
#   <EBox::Common::Model::EnableFrom> inside a top-bottom
#   layout.
#

package EBox::Events::Model::GeneralComposite;

use base 'EBox::Model::Composite';

use strict;
use warnings;

## eBox uses
use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#         Constructor for the general events composite
#
# Returns:
#
#       <EBox::Events::Model::GeneralComposite> - a
#       general events composite
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
                             'EnableForm',
                             'ConfigurationComposite',
                            ],
         layout          => 'top-bottom',
         name            => 'GeneralComposite',
         printableName   => __('Events'),
         compositeDomain => 'Events',
         help            => __('Events module may help you to make eBox ' .
                               'inform you about events that happen at eBox ' .
                               'in some different ways'),
        };

      return $description;

  }

1;
