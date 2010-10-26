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

open (my $T_ACCOUNT, '<.\templates\pidgin\accounts.xml')
    or die "Error: $^E\n";

my $account = join ('', <$T_ACCOUNT>);

$account =~ s/USERNAME/$USER/g;
$account =~ s/ZENTYALDOMAIN/zentyal/g;
$account =~ s/ZENTYALSERVER/$SERVER/g;

open (my $T_BLIST, '<./templates/pidgin/blist.xml')
    or die "Error: $^E\n";

my $blist = join ('', <$T_BLIST>);
$blist =~ s/USERNAME/$USER/g;
$blist =~ s/ZENTYALDOMAIN/ebox/g;

print $account;

open (my $ACCOUNT, ">$APPDATA/.purple/accounts.xml") or
    die "Error: $^E\n";

print $ACCOUNT $account;

open (my $BLIST, ">$APPDATA/.purple/blist.xml") or
    die "Error: $^E\n";

print $BLIST $blist;
