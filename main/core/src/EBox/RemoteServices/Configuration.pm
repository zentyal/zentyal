# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::RemoteServices::Configuration;
# Class: EBox::RemoteServices::Configuration
#
#   This class is a configuration variable holder shared between
#   several objects in remote services module
#

use EBox::Config;
use EBox::Global;

# Group: Public class methods

# Method: APIEndPoint
#
#      Get the API end point
#
# Returns:
#
#      String - the API end point (host part)
#
sub APIEndPoint
{
    my $rsAPIKey = EBox::Config::configkey('rs_api');
    if ( defined($rsAPIKey) ) {
        $rsAPIKey =~ s:/.*::g;
    }

    return $rsAPIKey;
}

# Method: aptQASourcePath
#
#      Return the path to the QA repository source
#
# Returns:
#
#      String - the path
#
sub aptQASourcePath
{
    return '/etc/apt/sources.list.d/zentyal-qa.list';
}

# Method: aptQAPreferencesPath
#
#      Return the path to the preferences file
#
# Returns:
#
#      String - the path
#
sub aptQAPreferencesPath
{
    return '/etc/apt/preferences.d/01zentyal';
}

# Method: aptQAConfPath
#
#      Return the path to the configuration file for QA repository
#
# Returns:
#
#      String - the path
#
sub aptQAConfPath
{
    return '/etc/apt/apt.conf.d/99zentyal';
}

1;
