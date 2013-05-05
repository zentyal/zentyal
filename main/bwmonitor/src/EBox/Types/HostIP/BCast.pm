# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::Types::HostIP::BCast;

use base 'EBox::Types::HostIP';

# TODO: Move this to core in 2.3 if it can be useful elsewhere?

sub new
{
    my $class = shift;
    my %opts = @_;

    my $self = $class->SUPER::new(%opts);

    bless($self, $class);
    return $self;
}

# Method: _paramIsValid
#
#     Check if the params has a correct host IP address
#     or a broadcast address
#
# Overrides:
#
#     <EBox::Types::HostIP::_paramIsValid>
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    my $value = $params->{$self->fieldName()};

    if (defined ($value)) {
        # TODO: support other addresses with partial 255?
        if ($value eq '255.255.255.255') {
            return 1;
        }
        EBox::Validate::checkIP($value, $self->printableName());
    }

    return 1;
}

1;
