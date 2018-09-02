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

# Class: EBox::WebServer::PlatformPath
#
#      This class stores every platform dependant path and it is
#      exposed in static method way.
#
use strict;
use warnings;

package EBox::WebServer::PlatformPath;

# Method: ConfDirPath
#
#      Get the directory path where all apache2 configuration lies.
#
#      (Static method)
#
# Returns:
#
#      String - the platform dependant path
#
sub ConfDirPath
{
    return '/etc/apache2';
}

# Method: DocumentRoot
#
#      Get the document root where default virtual host content will be
#      stored.
#
#      (Static method)
#
# Returns:
#
#      String - the platform dependant path
#
sub DocumentRoot
{
    return '/var/www';
}

# Method: VDocumentRoot
#
#      Get the document root where created virtual hosts content will be
#      stored.
#
#      (Static method)
#
# Returns:
#
#      String - the platform dependant path
#
sub VDocumentRoot
{
    return '/srv/www';
}

# Method: Apache2Path
#
#      Get the apache2 daemon program from where manage Apache2 daemon.
#
# Returns:
#
#      String - the platform dependant path
#
sub Apache2Path
{
    return '/usr/sbin/apache2';
}

1;
