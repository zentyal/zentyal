# Copyright (C) 2011-2014 Zentyal S.L.
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

package EBox::CaptivePortal::CGI::Base;
use base 'EBox::CGI::ClientBase';

use EBox::Gettext;

# Method: _validateReferer
#
#   Checks whether the referer header has valid information. For Captive Portal, it's completely disabled.
#
# Overrides: <EBox::CGI::ClientBase::_validateReferer>
#
sub _validateReferer
{
}

1;
