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

package ZentyalDesktop::Services::VoIP;

use ZentyalDesktop::Config qw(ZENTYAL_DESKTOP_DIR SKEL_DIR);

sub configure
{
    my ($class, $server, $user, $data) = @_;

    # Ekiga configuration
    my $EKIGATMPL = SKEL_DIR . '/ekiga.gconf';
    my $EKIGACONF = ZENTYAL_DESKTOP_DIR . '/ekiga.gconf';
    system("cp $EKIGATMPL $EKIGACONF");

    my $ekigaLink = '/usr/share/applications/ekiga.desktop';

    unless (-f $ekigaLink) {
        return;
    }

    my $HOME = $ENV{HOME};
    my $LOCAL_APPS = "$HOME/.local/share/applications";

    system ("mkdir -p $LOCAL_APPS");
    system ("cp $ekigaLink $LOCAL_APPS");

    my $ekigaLauncher = '/usr/share/zentyal-desktop/ekiga-launcher';
    system ("sed -i 's:^Exec=ekiga:Exec=$ekigaLauncher:' $LOCAL_APPS/ekiga.desktop");
}

1;
