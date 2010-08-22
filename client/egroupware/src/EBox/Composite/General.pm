# Copyright (C) 2009-2010 eBox Technologies S.L.
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

# Class: EBox::EGroupware::Composite::General
#
#   This class is used to manage the eGroupware module within a single
#   element whose components are: <EBox::EGroupware::Model::Applications> and
#   <EBox::EGroupware::Model::VMailDomain> inside a top-bottom
#   layout.
#

package EBox::EGroupware::Composite::General;

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
                                'VMailDomain',
                                'DefaultApplications',
                                'PermissionTemplates',
                               ],
            layout          => 'tabbed',
            name            =>  __PACKAGE__->nameFromClass,
            pageTile => __('eGroupware'),
            compositeDomain => 'EGroupware',
            help            => __('Once the module is enabled and you have created a user account, you can access the eGroupware web interface at http://<ebox_ip>/egroupware'),
        };

    return $description;
}

# Method: pageTitle
#
#   Overrides <EBox::Model::Composite::pageTitle>
sub pageTitle
{
    return __('EGroupware');
}

1;
