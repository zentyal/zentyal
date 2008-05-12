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

# Class: EBox::DHCP::Model::General
#
#   This class is used to display the ebox dhcp module as in a whole
#   allowing configure a DHCP server to configure in every static
#   interface
#

package EBox::DHCP::Composite::General;

use base 'EBox::Model::Composite';

use strict;
use warnings;

## eBox uses
use EBox::Gettext;
use EBox::Global;

# Group: Public methods

# Constructor: new
#
#         Constructor for the general dhcp composite
#
# Returns:
#
#       <EBox::DHCP::Model::General> - a
#       general dhcp composite
#
sub new
  {

      my ($class) = @_;

      my $self = $class->SUPER::new();

      return $self;

  }

# Method: precondition
#
# Overrides:
#
#        <EBox::Model::Composite::precondition>
#
sub precondition
{
    my $netMod = EBox::Global->modInstance('network');
    my @allIfaces = @{$netMod->allIfaces()};
    my $nStatic = grep { $netMod->ifaceMethod($_) eq 'static' }
      @allIfaces;
    return ($nStatic > 0);
}

# Method: preconditionFailMsg
#
# Overrides:
#
#        <EBox::Model::Composite::preconditionFailMsg>
#
sub preconditionFailMsg
{
    return __x('An interface must set as static '
               . 'to configure the DHCP service on it. To '
               . 'do so, change {openhref}interfaces '
               . 'configuration{closehref} in network module',
              openhref  => '<a href="/ebox/Network/Ifaces">',
              closehref => '</a>');
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
                             'Interfaces',
                            ],
         layout          => 'top-bottom',
         name            => 'General',
         printableName   => 'DHCP',
         compositeDomain => 'DHCP',
        };

      return $description;

  }

1;
