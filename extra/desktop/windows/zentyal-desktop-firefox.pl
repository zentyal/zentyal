#!perl
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

use strict;
use warnings;

use Win32::TieRegistry(Delimiter=>"#", ArrayValues=>0);
use Win32::Process;

$Registry->Delimiter("/");
my $VERSION= $Registry->{"LMachine/SOFTWARE/Mozilla/Mozilla Firefox/CurrentVersion"}
    or die "Error: $^E\n";

my $EXEC_PATH= $Registry->{"LMachine/SOFTWARE/Mozilla/Mozilla Firefox/$VERSION/Main/PathToExe"}
    or die "Error: $^E\n";

my $args = '-CreateProfile Default2';
my $process;
Win32::Process::Create($process,$EXEC_PATH, "$EXEC_PATH $args",0,0,'.') 
    or die "Error: $^E\n";


my $SERVER = '192.168.1.135'; # FIXME: unhardcode this
my $ICON = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABmJLR0QA/gD+AP7rGNSCAAAACXBIWXMAAABIAAAASABGyWs+AAAACXZwQWcAAAAQAAAAEABcxq3DAAAA9UlEQVQ4y7WRMU7DQBBF32xW0FBCzAXiUJAcgHCQcAUUzFli5Q5AxyEIUupEAswF4khUNBTgpcGj3cR2IhC/+jt//8zfWfgj5Obh1NWJF+cLWY47tfrx9atYgOFgzsfnO/utAxXvHvvKD0dPGIxndawmJwDYsnQ/O6uN6YDVpKvn9uhZuTYYDuaB6XbaU95CApMPW2VYxxfw9hP5lwloTtA0HdCF/Qu2/vM2neW446pQGn19nQdLzNNYO0dJtjGtKAraVy8bdcMOyNMYKQ+uCIbt1CBKMhwgIiCGo8uFata/1ARjDHkaEyUZxu6FDfxIdU+o4gDfVFV7/yoGZqUAAAAASUVORK5CYII=";


my $PATH_BOOKMARKS = ' '; # FIXME: search path

open (my $BOOKMARKS, $PATH_BOOKMARKS)
    or die "Error: $^E\n"


my $bookmarks = join ('', <$BOOKMARKS>);

$bookmarks =~ /PERSONAL_TOOLBAR_FOLDER/{N;N;a\<DT><A HREF=\"$URL\" ICON=\"data:image/png;base64,$ICON_DATA\">$DESC</A>}/;
