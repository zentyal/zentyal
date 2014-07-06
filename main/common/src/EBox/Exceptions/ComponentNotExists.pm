# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::Exceptions::ComponentNotExists;
use base 'EBox::Exceptions::Internal';

use Log::Log4perl;

# Constructor: new
#
#     This exception is used when a component (model, composite, ..) does not exists
#
sub new
{
    my ($class, @args) = @_;

    $self = $class->SUPER::new(@args);
    bless ($self, $class);

    return $self;
}

1;
