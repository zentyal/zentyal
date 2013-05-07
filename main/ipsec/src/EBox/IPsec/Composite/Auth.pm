# Copyright (C) 2011-2013 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU VPNConfiguration Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU VPNConfiguration Public License for more details.
#
# You should have received a copy of the GNU VPNConfiguration Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# Class: EBox::IPsec::Composite::Auth
#
#

use strict;
use warnings;

package EBox::IPsec::Composite::Auth;

use base 'EBox::Model::Composite';

use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#         Constructor for the authentication composite
#
# Returns:
#
#       <EBox::IPsec::Composite::Auth>
#
sub new
{
      my ($class, @params) = @_;

      my $self = $class->SUPER::new(@params);

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
         layout          => 'top-bottom',
         name            => 'Auth',
         compositeDomain => 'IPsec',
         printableName   => __('Authentication'),
      };

      return $description;
}

1;
