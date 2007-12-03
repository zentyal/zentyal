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

# Class: EBox::WebService::Model::GeneralComposite
#
#   This class represents the three configuration items for the web
#   service.
#
#    - Enable/Disable the service through a simple form
#    - Configuration setting within a simple form
#    - A table with the user defined virtual hosts
#

package EBox::WebServer::Composite::General;

use base 'EBox::Model::Composite';

use strict;
use warnings;

## eBox uses
use EBox::Gettext;
use EBox::Global;

# Group: Public methods

# Constructor: new
#
#         Constructor for the general web service composite
#
# Returns:
#
#       <EBox::WebService::Model::GeneralComposite> - the
#       web service general composite
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

    my $wsMod = EBox::Global->modInstance('webserver');

    my $description =
      {
       components      => [
                           '/' . $wsMod->name() . '/EnableForm',
                           '/' . $wsMod->name() . '/GeneralSettings',
                           '/' . $wsMod->name() . '/VHostTable',
                          ],
       layout          => 'top-bottom',
       name            => 'General',
       printableName   => __('Web service'),
       compositeDomain => 'Web',
       help            => __('The eBox web service allows you ' .
                             'to host Web pages in plain HTML ' .
                             'within different virtual hosts'),
      };

    return $description;

}

1;
