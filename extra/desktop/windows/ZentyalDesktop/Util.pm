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

package ZentyalDesktop::Util;

use ZentyalDesktop::Config;

use Win32::TieRegistry(Delimiter => '/', ArrayValues => 0);
use Win32::Process;

sub createFirefoxProfile
{
    my $config = ZentyalDesktop::Config->instance();

    my $appData = $config->appData();

    my $args = '-CreateProfile default';
    my $process;
    my $exePath = _firefoxExePath();

    Win32::Process::Create($process, $exePath, "$exePath $args", 0, 0, '.');

    my $profilesPath = "$appData/Mozilla/Firefox/Profiles/";
    $profilesPath =~ s/\\/\//g;
    opendir (my $dir, $profilesPath)
        or return;

    my @files = readdir ($dir);
    my $profileDir;
    foreach my $file (@files) {
        if ($file =~ /default/) {
            $profileDir = $file;
            last;
        }
    }

    closedir ($dir);

    $config->setFirefoxBookmarksFile("$profilesPath/$profileDir/bookmarks.html");
}

# TODO: This function should be common
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

sub _firefoxExePath
{
    my $version = $Registry->{"LMachine/SOFTWARE/Mozilla/Mozilla Firefox/CurrentVersion"};
    my $path = $Registry->{"LMachine/SOFTWARE/Mozilla/Mozilla Firefox/$version/Main/PathToExe"};

    return $path;
}

1;
