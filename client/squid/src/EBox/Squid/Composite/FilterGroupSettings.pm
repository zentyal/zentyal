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

# Class: EBox::Squid::Composite::FilterSettings
#
#   This class is used to manage the events module within a single
#   element whose components
#   are: <EBox::Events::Model::ConfigurationComposite> and
#   <EBox::Common::Model::EnableFrom> inside a top-bottom
#   layout.
#

package EBox::Squid::Composite::FilterGroupSettings;

use base 'EBox::Model::Composite';

use strict;
use warnings;

use EBox::Gettext;


# Group: Public methods

# Constructor: new
#
#         Constructor for the general events composite
#
# Returns:
#
#       <EBox::Squid::Model::GeneralComposite> - a
#       general events composite
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
         components      => [
                            'FilterGroupContentFilterThreshold',
                             'FilterGroupTabs',
                            ],
         layout          => 'top-bottom',
         name            => 'FilterGroupSettings',
         printableName   => __('Filter settings'),
         compositeDomain => 'Squid',
#         help            => __(''),
        };

      return $description;

  }


sub pageTitle
{
    my ($self) = @_;
    my $parentRow = $self->parentRow();
    my $profile = $parentRow->elementByName('name')->printableValue();
    my $title = __x(
            'Filter settings for profile {p}',
                    p => $profile,
                   );

    
    return $title;
}


1;
