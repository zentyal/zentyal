# Copyright (C) 2010-2011 Zentyal S.L.
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

package EBox::Jabber::Composite::General;

use base 'EBox::Model::Composite';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#         Constructor for the general jabber server composite.
#
# Returns:
#
#       <EBox::WebService::Model::GeneralComposite> - the
#       web service general composite.
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

    my $wsMod = EBox::Global->modInstance('jabber');

    my $description =
      {
       components      => [
                           '/' . $wsMod->name() . '/GeneralSettings',
                          ],
       layout          => 'top-bottom',
       name            => 'General',
       printableName   => __('Configuration'),
       pageTitle       => __('Jabber'),
       compositeDomain => 'Jabber',
       help            => __(''),
      };

    return $description;
}

1;
