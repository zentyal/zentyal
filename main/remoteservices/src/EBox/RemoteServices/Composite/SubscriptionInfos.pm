# Copyright (C) 2011 eBox Technologies S.L.
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

# Class: EBox::RemoteServices::Composite::Subscriptions
#
#    Display the form and information about subscriptions
#

package EBox::RemoteServices::Composite::SubscriptionInfos;

use base 'EBox::Model::Composite';

use strict;
use warnings;

use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#       Constructor for the subscription composite
#
# Returns:
#
#       <EBox::RemoteServices::Composite::Subscriptions> - the subscription composite
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
              'SubscriptionInfo',
              'QAUpdatesInfo',
              'AlertsInfo',
              'ReportsInfo',
             ],
          layout          => 'tabbed',
          name            => 'SubscriptionInfos',
          compositeDomain => 'RemoteServices',
        };

    return $description;

}

1;
