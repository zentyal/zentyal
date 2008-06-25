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

package EBox::Samba::Types::Select;

use strict;
use warnings;

use base 'EBox::Types::Select';

sub new
{
        my $class = shift;
        my %opts = @_;

        my $self = $class->SUPER::new(%opts);

        bless($self, $class);
        return $self;
}


# Method: options
#
#   Overrides <EBox::Types::Select::options> to not cache the options.
#
#   This is needed for the SambaSharePermissions model, as this
#   options are populated from the users stored in LDAP and they might change.
#
#   It would make more sense to add an attribute to the type, or waiting
#   until we have a proper user model, and this will be done automatically
#
#
#
sub options
{
    my ($self) = @_;

    my $populateFunc = $self->populate();
    return &$populateFunc();
}

1;
