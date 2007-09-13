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

# Class: EBox::DNS::Model::DNSComposite
#
#   This class is used to manage the dns module within a single
#   element whose components
#   are: <EBox::Events::Model::EnableFormDNS> and
#   <EBox::Common::Model::DomainTable> inside a top-bottom
#   layout.
#

package EBox::DNS::Model::DNSComposite;

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
#       <EBox::DNS::Model::GeneralComposite> - a
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
                             'EnableFormDNS',
                             'DomainTable',
                            ],
         layout          => 'top-bottom',
         name            => 'DNSComposite',
         printableName   => __('DNS'),
         compositeDomain => 'DNS',
         help            => __('The DNS server allows you to resolve names'
              	 			.' for your own domains.'),
        };

      return $description;

  }

1;
