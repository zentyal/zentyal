# Copyright (C) 2010-2013 Zentyal S.L.
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

package ZentyalDesktop::VoIP;

use ZentyalDesktop::Config qw(TEMPLATES_DIR);
use ZentyalDesktop::Log;

my $logger = ZentyalDesktop::Log::logger();

sub configure
{
    my ($class, $server, $user, $data) = @_;
    $logger->debug("VoIP configure -> server: $server user: $user");

    my $password = '';

    my $config = ZentyalDesktop::Config->instance();
    my $APPDATA = $config->appData();

    my $TEMPLATES_DIR = TEMPLATES_DIR;

    my $password = ' ';

    open (my $templateFH, '<', "$TEMPLATES_DIR/ekiga.conf");
    my $template = join ('', <$templateFH>);
    close ($templateFH);

    $template =~ s/USERNAME/$user/g;
    $template =~ s/SERVER/$server/g;
    $template =~ s/PASSWORD/$password/g;

    open (my $confFH, '>', "$APPDATA/ekiga.conf");
    print $confFH $template;
    close ($confFH);
}

1;
