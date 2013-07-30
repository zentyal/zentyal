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

package ZentyalDesktop::Util;

use ZentyalDesktop::Config;

sub createFirefoxProfile
{
    # Create firefox default profile and get its path
    my $cmd = 'firefox -CreateProfile default 2>&1 |
               cut -d\\\' -f4 |
               sed "s/prefs.js$/bookmarks.html/"';
    my $bookfile = `$cmd`;
    chomp ($bookfile);
    my $config = ZentyalDesktop::Config->instance();
    $config->setFirefoxBookmarksFile($bookfile);
}

sub addFirefoxBookmark
{
    my ($url, $desc) = @_;

    my $config = ZentyalDesktop::Config->instance();
    my $file = $config->firefoxBookmarksFile();
    my $icon = ZentyalDesktop::Config::ZENTYAL_ICON_DATA;


    open (my $FH, '<', $file);
    my @lines = <$FH>;
    close ($FH);

    my $bookmark = "<DT><A HREF=\"$url\" ICON=\"data:image/png;base64,$icon\">$desc</A>";

    # Append the bookmark two lines before the match
    my $index = 0;
    for my $line (@lines) {
        $index++;
        last if ($line =~ /PERSONAL_TOOLBAR_FOLDER/);
    }
    if ($index + 2 < scalar (@lines)) {
        splice (@lines, $index + 2, 0, $bookmark);
    }

    open (my $FH, '>', $file);
    print $FH join ('', @lines);
    close ($FH);
}

1;
