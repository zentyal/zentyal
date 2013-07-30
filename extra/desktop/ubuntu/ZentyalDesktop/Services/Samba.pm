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

package ZentyalDesktop::Services::Samba;

sub configure
{
    my ($class, $server, $user, $data) = @_;

    my $DESKTOP_DIR = `xdg-user-dir DESKTOP`;
    chomp ($DESKTOP_DIR);

    unless (-d $DESKTOP_DIR) {
        mkdir ($DESKTOP_DIR);
    }

    create_desktop_link($DESKTOP_DIR, $server, $user,
                        $user, "$user\'s share");

    my $gids = `id -G`;
    chomp ($gids);
    my @groups = split (' ', $gids);

    # Insert group conferences in buddy list
    for my $gid (@groups) {
        if ($gid >= 2001) {
            my $groupname = getgrgid($gid);
            my $share = $data->{groupShares}->{$groupname}->{share};
            my $desc = $data->{groupShares}->{$groupname}->{desc};
            create_desktop_link($DESKTOP_DIR, $server, $user,
                                $share, $desc);
        }
    }
}

sub create_desktop_link
{
    my ($dir, $server, $user, $share, $desc) = @_;

    open (my $FH, '>', "$dir/$share.desktop");

    print $FH "#!/usr/bin/env xdg-open\n";
    print $FH "[Desktop Entry]\n";
    print $FH "Version=1.0\n";
    print $FH "Type=Link\n";
    print $FH "Name=$share\n";
    print $FH "Comment=$desc\n";
    print $FH "URL=smb://$user\@$server/$share\n";

    close ($FH);
}

1;
