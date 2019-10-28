# Copyright (C) 2012-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::SysInfo::Composite::SmartAdmin;

use base 'EBox::Model::Composite';

use EBox::Gettext;
use EBox::Global;

# Group: Public methods

# Constructor: new
#
#   Constructor for the general System composite
#
# Returns:
#
#   <EBox::SysInfo::Model::General> - the newly create object
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
#   <EBox::Model::Composite::_description>
#
sub _description
{
    my $description = {
                        layout          => 'top-bottom',
                        name            => __PACKAGE__->nameFromClass,
                        printableName   => __('Smart Admin'),
                        pageTitle       => __('Smart Admin'),
                        compositeDomain => 'SysInfo',
                        help => __('On this page you can configure and get different system informations')
    };

    return $description;
}

1;
