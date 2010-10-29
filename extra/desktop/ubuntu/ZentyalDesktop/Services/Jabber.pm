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

sub configure
{
    my ($server, $user, $data) = @_;

    my $domain = $data->{domain};

    my $HOME = $ENV{HOME};
    my $PIDGIN_DIR = "$HOME/.zentyal-desktop/pidgin";

    # Replace variables in pidgin config template
    system ("sed -i \"s/USERNAME/$user/g\" $PIDGIN_DIR/accounts.xml");
    system ("sed -i \"s/ZENTYALDOMAIN/$domain/g\" $PIDGIN_DIR/accounts.xml");
    system ("sed -i \"s/ZENTYALSERVER/$server/g\" $PIDGIN_DIR/accounts.xml");
    system ("sed -i \"s/USERNAME/$user/g\" $PIDGIN_DIR/blist.xml");
    system ("sed -i \"s/ZENTYALDOMAIN/$domain/g\" $PIDGIN_DIR/blist.xml");

    my @groups = split (' ', `id -G`);

    # Insert group conferences in buddy list
    for my $gid (@groups) {
        if ($gid >= 2001) {
            my (undef, undef, undef, $groupname) = getgrgid($gid);
            add_conference($server, $user, $domain, $groupname);
        }
    }

    system ("mv $PIDGIN_DIR $HOME/.purple");
}

sub add_conference
{
    my ($server, $user, $domain, $group) = @_;

    my $regex = "/<group/a\
                <chat proto='prpl-jabber' account='$user@$domain/zentyaluser'>\n\
\t\t\t<component name='handle'>$user</component>\n\
\t\t\t<component name='room'>$group</component>\n\
\t\t\t<component name='server'>conference.$domain</component>\n\
\t\t</chat>\n";

    system ("sed -i "$regex" $PIDGIN_DIR/blist.xml");
}
