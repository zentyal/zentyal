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

# Class: EBox::Squid::Composite::General
#
#   This class is used to manage the events module within a single
#   element whose components
#   are: <EBox::Events::Model::ConfigurationComposite> and
#   <EBox::Common::Model::EnableFrom> inside a top-bottom
#   layout.
#

package EBox::Squid::Composite::FilterGroupDomains;

use base 'EBox::Model::Composite';

use strict;
use warnings;

use EBox::Gettext;


# Group: Public methods

sub new
  {

      my ($class, @params) = @_;

      my $self = $class->SUPER::new(@params);

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
                             'UseDefaultDomainFilter',
                            'FilterGroupDomainFilterSettings',
                            'FilterGroupDomainFilter',
                            'FilterGroupDomainFilterFiles',
                            ],
         layout          => 'top-bottom',
         name            => 'FilterGroupDomains',
         printableName   => __('Domains filtering for filter group'),
         compositeDomain => 'Squid',
#         help            => __(''),
        };

      return $description;

  }




1;
