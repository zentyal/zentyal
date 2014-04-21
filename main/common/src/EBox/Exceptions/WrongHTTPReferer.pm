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
use strict;
use warnings;

package EBox::Exceptions::WrongHTTPReferer;
use base 'EBox::Exceptions::External';

use EBox::Gettext;

# Constructor: new
#
#      An exception called when a request  referer is not valid
#
# Parameters:
#
#      text - the localisated text to show to the user (Default: standard wrong
#      HTTP referer text)
#
sub new
{
    my ($class, $msg, @params) = @_;
    if (not $msg) {
        $msg = __("Wrong HTTP referer detected, operation cancelled for security reasons");
    }

    my $self = $class->SUPER::new($msg, @params);
    bless ($self, $class);
    return $self;
}

1;
