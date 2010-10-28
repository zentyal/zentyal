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
my $APPDATA= $Registry->{"CUser/Volatile Environment/APPDATA"}
    or die "Error: $^E\n";

my $USER = $ENV{USERNAME};
my $SERVER = '192.168.1.135'; # FIXME: unhardcode this
my $PASSWORD = ' ';

open (my $T_EKIGA_CONF, '<./templates/ekiga.conf')
    or die "Error: $^E\n";

my $conf = join ('', <$T_EKIGA_CONF>);


$conf =~ s/USERNAME/$USER/g;
$conf =~ s/SERVER/$SERVER/g;
$conf =~ s/PASSWORD/$PASSWORD/g;

print $conf;
print $APPDATA;

open (my $EKIGA_CONF, ">$APPDATA/ekiga.conf") or
    die "Error: $^E\n";

print $EKIGA_CONF $conf;
