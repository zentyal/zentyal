# Copyright (C) 2012-2013 Zentyal S.L.
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

use Test::More qw(no_plan);

use lib '../..';
use EBox::EBackup;
use EBox::Sudo;

sub escapeFileTest
{
    my $url = 'file:///mnt/backup';
    my $date = '2011-01-01 10:32:12';

    my @cases  = (
        '/tmp/ea',
        '/tmp',
        q{/tmp/o'hara},
        q{/tmp/con espacio},
        q{/tmp/o' espacio},
        q{/home/jsalamero/foobar/L'Op},
        q{/tmp/Köln/son monos},
        q{/tmp/doble""quote},
        q{/tmp/both'quotes"},
        q{*.txt},
        q{\.txt},
        q{-.txt},
        q{--.txt},
        q{$.txt},
        q{$$.txt},
        q|{ }.txt|,
        q{&.txt},
        q{`.txt},
        q{``.txt},
        q{''.txt},
        q{ España!.txt},
        q{Estoy <stwisted>.txt},
        q{Tras la |.txt},
        q{¿O qué?.txt},
        q{Me es =.txt},
        q{Dame un ().txt},
        q{Estoy al 100%.txt},
       );

    foreach my $file (@cases) {
        my $escaped = EBox::EBackup->_escapeFile($file);
        my $lsCmd = "ls $escaped > /dev/null";
        system $lsCmd;
        my $returnValue = $!;
        my $escapeOk = ($returnValue == 2) || ($returnValue == 0);
        ok $escapeOk, "Escape $file -> $escaped";

        my $sudoCmd = '/usr/bin/sudo ' . $lsCmd;
        system $sudoCmd;
        $returnValue = $!;
        $escapeOk = ($returnValue == 2) || ($returnValue == 0);
        ok $escapeOk, "Sudo command accepted $sudoCmd";
    }
}

print "You need to have sudo permission witohut password for the ls command to run smoothly this test\n";
escapeFileTest();
1;
