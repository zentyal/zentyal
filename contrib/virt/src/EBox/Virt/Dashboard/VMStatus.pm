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

package EBox::Virt::Dashboard::VMStatus;

use base 'EBox::Dashboard::Item';

use EBox::Gettext;

# Constructor: new
#
#     Create a Dashboard VM status item
#
# Named parameters:
#
#     name    - String with the virtual machine name
#
#     running - Boolean indicating whether the virtual machine is
#               running or not
#
sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new();
    while(my ($key, $value) = each(%params)) {
        $self->{$key} = $value;
    }
    $self->{'type'} = 'status';
    bless($self, $class);
    return $self;
}

sub HTMLViewer()
{
    return '/virt/vmstatus.mas';
}

1;
