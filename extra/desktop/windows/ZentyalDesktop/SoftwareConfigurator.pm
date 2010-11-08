# Copyright (C) 2010 eBox Technologies S.L.
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

package ZentyalDesktop::SoftwareConfigurator;

use ZentyalDesktop::Util;
use ZentyalDesktop::LDAP;

use ZentyalDesktop::Jabber;
use ZentyalDesktop::Mail;
use ZentyalDesktop::Samba;
use ZentyalDesktop::UserCorner;
use ZentyalDesktop::VoIP;
use ZentyalDesktop::Zarafa;
use ZentyalDesktop::Log;
use Switch;

my $logger = ZentyalDesktop::Log::logger();

sub configure
{
    $logger->debug("FIXME: configuration");
    my ($class, $server, $user) = @_;

    ZentyalDesktop::Util::createFirefoxProfile();

    my $ldap = new ZentyalDesktop::LDAP($server, $user);

    my $services = $ldap->servicesInfo();

    foreach my $service (keys %{$services}) {
        $logger->debug("Service: $service");
         my $data = $services->{$service};
        switch ($service) {
            case 'Jabber' {ZentyalDesktop::Jabber->configure($server,$user,$data); }
            case 'Mail' {ZentyalDesktop::Mail->configure($server,$user,$data); }
            case 'Samba' {ZentyalDesktop::Samba->configure($server,$user,$data); }
            case 'UserCorner' {ZentyalDesktop::UserCorner->configure($server,$user,$data); }
            case 'VoIP' {ZentyalDesktop::VoIP->configure($server,$user,$data); }
            case 'Zarafa' {ZentyalDesktop::Zarafa->configure($server,$user,$data); }
        }
    }

#    my $data = $services->(Jabber);

}

1;
