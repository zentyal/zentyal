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

$Registry->Delimiter("/");
my $VERSION= $Registry->{"LMachine/SOFTWARE/Mozilla/Mozilla Firefox/CurrentVersion"}
    or die "Error: $^E\n";

my $EXEC_PATH= $Registry->{"LMachine/SOFTWARE/Mozilla/Mozilla Firefox/$VERSION/Main/PathToExe"}
    or die "Error: $^E\n";

system('"' . $EXEC_PATH . '-CreateProfile Default\"');

my $args = '-CreateProfile Default';
my $process;
Win32::Process::Create($process,$EXEC_PATH, "$EXEC_PATH $args",0,0,'.') 
    or die "Error: $^E\n";




my $USER = $ENV{USERNAME};
my $SERVER = '192.168.1.135'; # FIXME: unhardcode this


