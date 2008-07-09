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

# Class: EBox::DHCP::Model::Interfaces
#
#   This class is used to display in a select form those interface
#   configuration composites to configure the DHCP server. This
#   composite is just a container for
#   <EBox::DHCP::Model::InterfaceConfiguration> composites indexed by
#   interface's name
#

package EBox::DHCP::Composite::Interfaces;

use base 'EBox::Model::Composite';

use strict;
use warnings;

## eBox uses
use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#         Constructor for the interfaces dhcp composite
#
# Returns:
#
#       <EBox::DHCP::Model::Interfaces> - a
#       interfaces dhcp composite
#
sub new
  {

      my ($class) = @_;

      my $self = $class->SUPER::new();

      return $self;

  }

# Method: pageTitle
#
#   Overrides:
#       
#       <EBox::Model::Composite::headTitle>
#
# Returns:
#
#
#   undef
sub pageTitle 
  {
    return undef;
  }

# Method: pageTitle
#
#   Overrides:
#       
#       <EBox::Model::Composite::headTitle>
#
# Returns:
#
#
#   undef
sub headTitle 
  {
    my ($self) = @_;
    $self->printableName();
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
                             '/dhcp/InterfaceConfiguration/*',
                            ],
         layout          => 'select',
         name            => 'Interfaces',
         compositeDomain => 'DHCP',
         selectMessage   => __('Choose a static interface to configure:'),
         printableName   => __('Service configuration'),
         help            => __('In order to serve IP addresses on an interface, '
                               . 'it is required to set at least a range or a '
                               . 'fixed address.'),
        };

      return $description;

  }

1;
