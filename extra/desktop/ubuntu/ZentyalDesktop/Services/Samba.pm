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

package ZentyalDesktop::Services::Samba;

sub configure
{
    my ($server, $user, $data) = @_;

    my $DESKTOP_DIR = `xdg-user-dir DESKTOP`;

    unless (-d $DESKTOP_DIR) {
        mkdir ($DESKTOP_DIR);
    }

    create_desktop_link($server, $user, $user, "$user\'s share");

    my @groups = split (' ', `id -G`);

    # Insert group conferences in buddy list
    for my $gid (@groups) {
        if ($gid >= 2001) {
            my (undef, undef, undef, $groupname) = getgrgid($gid);
            my $share = $data->{groupShares}->{$groupname}->{name};
            my $desc = $data->{groupShares}->{$groupname}->{desc};
            create_desktop_link($server, $user, $share, $desc);
        }
    }
}

sub create_desktop_link
{
    my ($server, $user, $share, $desc) = @_;

    my $linkfile = "$DESKTOP_DIR/$share.desktop";

    open (my $FH, ">$linkfile");
    print $FH "#!/usr/bin/env xdg-open";
    print $FH "[Desktop Entry]";
    print $FH "Version=1.0";
    print $FH "Type=Link";
    print $FH "Name=$share";
    print $FH "Comment=$desc";
    print $FH "URL=smb://$user@$server/$share";
    close ($FH);
}
