#!/usr/bin/perl
#
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

use warnings;
use strict;

use ZentyalDesktop::Config;
use ZentyalDesktop::SoftwareConfigurator;

use Win32::TieRegistry(Delimiter => '/', ArrayValues => 0);

eval { $Registry->{'CUser/Software/Zentyal/Zentyal Desktop/Configured'}; };
unless ($@) {
    exit 0;
}

my $config = ZentyalDesktop::Config->instance();
my $appData = $Registry->{'CUser/Volatile Environment/APPDATA'}
    or die "Error: $^E";
$config->setAppData($appData);

my $server = $Registry->{'LMachine/SOFTWARE/Zentyal/Zentyal Desktop/SERVER'}
    or die "Error: $^E";
my $user = $ENV{USERNAME};


my $firefoxProfilessPath = $appData . '/Mozilla/Firefox/Profiles/';
$firefoxProfilesPath =~ s/\\/\//g;
opendir (my $dir, $profilesPath)
    or die "Error: $^E\n";
my @files = readdir $dir;
my $profileDir;
foreach my $file (@files){
    if ($file =~ /default/){
        $profileDir = $file;
        last;
    };
};

$config->setFirefoxBookmarksFile($appData . '/Mozilla/Firefox/Profiles/' . $profileDir . 'bookmarks.html');

ZentyalDesktop::SoftwareConfigurator->configure($server, $user);

my $tips = $Registry->{'CUser/Software/'}->{'Zentyal/Zentyal Desktop'}
    or die "Error: $^E\n";
$tips{'/Configured'} = 1;


exit 0;
