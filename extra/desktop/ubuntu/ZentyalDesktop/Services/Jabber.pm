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

package ZentyalDesktop::Services::Jabber;

use ZentyalDesktop::Config qw(SKEL_DIR);

use Text::Template;

sub configure
{
    my ($server, $user, $data) = @_;

    my $domain = $data->{domain};

    my $HOME = $ENV{HOME};

    # Replace variables in pidgin config template

    my @gids = split (' ', `id -G`);

    # Insert group conferences in buddy list
    my $groups = '';
    for my $gid (@gids) {
        if ($gid >= 2001) {
            my (undef, undef, undef, $groupname) = getgrgid($gid);
            $groups .= _groupStr($server, $user, $domain, $groupname);
        }
    }

    my $confDir = "$HOME/.purple";
    mkdir ($confDir);

    my $template = new Text::Template(SOURCE => SKEL_DIR . '/pidgin/accounts.xml');
    $template->fill_in_file("$confDir/accounts.xml",
                            HASH => { user => $user,
                                      domain => $domain,
                                      server => $server });

    my $template = new Text::Template(SOURCE => SKEL_DIR . '/pidgin/blist.xml');
    $template->fill_in_file("$confDir/blist.xml",
                            HASH => { user => $user,
                                      domain => $domain,
                                      groups => $groups });
}

sub _groupStr
{
    my ($server, $user, $domain, $group) = @_;

# TODO: Check if conference.$domain should be $server
    my $group = "/<group/a\
                <chat proto='prpl-jabber' account='$user@$domain/zentyaluser'>\n\
\t\t\t<component name='handle'>$user</component>\n\
\t\t\t<component name='room'>$group</component>\n\
\t\t\t<component name='server'>conference.$domain</component>\n\
\t\t</chat>\n";
    return $group;
}

1;
