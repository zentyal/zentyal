# Copyright (C) 2008 Warp Networks S.L.
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

# Class: EBox::RemoteServices::Composite::General
#
#    Display the two forms that are exclusively used by remote
#    services
#

package EBox::RemoteServices::Composite::General;

use base 'EBox::Model::Composite';

use strict;
use warnings;

## eBox uses
use EBox::Gettext;

# Constants
use constant {
  EBOX_SERVICES_URL => 'http://www.ebox-technologies.com/products/controlcenter/try/'
                       . '?utm_source=ebox&utm_medium=ebox&utm_content=remoteservices'
                       . '&utm_campaign=register',
};

# Group: Public methods

# Constructor: new
#
#       Constructor for the general remote services composite
#
# Returns:
#
#       <EBox::RemoteServices::Composite::General> - the general composite
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
    my $printableName = __('eBox Control Center');

    my $description =
      {
          components      => [
              'Subscription',
              # 'AccessSettings',
             ],
          layout          => 'top-bottom',
          name            => 'General',
          compositeDomain => 'RemoteServices',
          printableName   => $printableName,
          pageTitle       => $printableName,
          help            => __x(' {openhref}Subscribing{closehref} your eBox to the Control Center '
                                 . 'lets you have automatic configuration backup and much more',
                                 openhref  => '<a href="' . EBOX_SERVICES_URL . '" target="_blank">',
                                 closehref => '</a>'),
      };

    return $description;

}

1;
