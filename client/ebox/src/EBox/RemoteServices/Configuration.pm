# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::RemoteServices::Configuration;

# Class: EBox::RemoteServices::Configuration
#
#   This class is a configuration variable holder shared between
#   several objects in remote services module
#

use strict;
use warnings;

use EBox::Config;

# Group: Public class methods

# Method: eBoxServicesMirrorCount
#
#      Get the count of mirror which supports subscription service
#
# Returns:
#
#      Int - the mirror count
#
sub eBoxServicesMirrorCount
{
    return EBox::Config::configkey('ebox_services_mirror_count');
}

# Method: DNSServer
#
#      Get the standard DNS server for eBox remote services
#
# Returns:
#
#      String - the IP address for the public DNS server
#
sub DNSServer
{
    return EBox::Config::configkey('ebox_services_nameserver');
}

# Method: PublicWebServer
#
#      Get the Web service name
#
# Returns:
#
#      String - the Web service name
#
sub PublicWebServer
{
    return EBox::Config::configkey('ebox_services_www');
}

1;
