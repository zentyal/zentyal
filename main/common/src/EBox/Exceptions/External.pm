# Copyright (C) 2004-2007 Warp Networks S.L.
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

package EBox::Exceptions::External;

use base 'EBox::Exceptions::Base';

use EBox::Gettext;

# Constructor: new
#
#      An exception called when a user defined parameter is wrong and
#      it is going to be shown to the user
#
# Parameters:
#
#      text - the localisated text to show to the user
#
sub new
{
    my $class = shift;

    local $Error::Depth = defined $Error::Depth ? $Error::Depth + 1 : 1;
    local $Error::Debug = 1;

    $self = $class->SUPER::new(@_);
    bless ($self, $class);

    $Log::Log4perl::caller_depth++;
    $self->log;
    $Log::Log4perl::caller_depth--;

    return $self;
}

1;
