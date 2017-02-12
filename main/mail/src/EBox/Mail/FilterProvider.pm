# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::Mail::FilterProvider;

# all eBox modules which provide a mail filter must subclass this package

# Method: mailFilter
#
#  return thes filter name and specifications. The specifications are a
#  reference to a hash with the following fields:
#    - active
#    - prettyName
#    - address
#    - port
#    - forwardPort
#    - instance
#    - module
#
#   if there is no filter available undef will be returned instead
#
# Returns:
#        - (name, specifications) of the available filter
#        - undef if there is not filter  avaialbe
#
# Warning: remember that the 'custom' name is reserved for user's custom
#   settings, so don't use it
sub mailFilter
{
  return undef;
}

# Method: mailFilterDashboard
#
#  add the custom dashboard values for the filter
#
#  Params:
#    - section
#
#  Returns:
#      - the given dashboard section
#
#  Default implementation:
#    doesn't add nothing to the dashboard section
sub mailFilterDashboard
{
  my ($self, $section) = @_;
  return $section;
}

# Method: mailFilterName
#
#  return the internal mail filter name
#

sub mailFilterName
{
  throw EBox::Exceptions::NotImplemented();
}

#  Method: mailMenuItem
#
#  reimplement this method if the filter needs to add a menu item to mail's menu
#
#  Returns:
#     undef if no menu item must be added or the EBox::Menu:Item to be added
sub mailMenuItem
{
  return undef;
}

1;
