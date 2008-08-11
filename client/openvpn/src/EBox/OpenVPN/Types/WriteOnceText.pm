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

# Class: EBox::OpenVPN::Types::WriteOnceText
#
# Class that inherits from <EBox::Type::Text>
# to add a needed feature due to the eBox openVPN module design.
#
# Text can only be written once, this is related to the way that
# the module manages the VPN files. To avoid nasty stuff, we don't
# allow to change the name of the VPN.
#
package EBox::OpenVPN::Types::WriteOnceText;

use strict;
use warnings;

use base 'EBox::Types::Text';

# eBox uses
use EBox;

# Group: Public methods

sub new
{
        my $class = shift;
        my %opts = @_;

        my $self = $class->SUPER::new(%opts);

        bless($self, $class);
        return $self;
}

# Method: editable
#
#   To implement write-once feature
#
# Overrides:
#
#       <EBox::Types::Abstract::editable>
#
sub editable
{
    my ($self) = @_;

    return (not (defined($self->value())));
}

1;
