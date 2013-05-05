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

# Class: EBox::Mail::Composite::General
#
#   This class is used to manage the events module within a single
#   element whose components
#   are: <EBox::Events::Model::ConfigurationComposite> and
#   <EBox::Common::Model::EnableFrom> inside a top-bottom
#   layout.
#

use strict;
use warnings;

package EBox::Mail::Composite::ServiceConfiguration;

use base 'EBox::Model::Composite';

use EBox::Gettext;

# Group: Public methods

# Method: pageTitle
#
# Overrides:
#
#   <EBox::Model::Component::pageTitle>
#
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
    my $description = {
       layout          => 'top-bottom',
       name            => __PACKAGE__->nameFromClass(),
       printableName   => __('Mail server options'),
       compositeDomain => 'Mail',
    };

    return $description;
}

1;
