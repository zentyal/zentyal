#!/usr/bin/perl -w

# Copyright (C) 2011 eBox Technologies S.L.
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

# This script measure the downloading time for the bandwidth

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Global;
use File::stat;
use File::Temp;
use LWP::Simple;
use Time::HiRes;

EBox::init();

my $url = 'http://download.thinkbroadband.com/5MB.zip';

my $tmpFile = new File::Temp();
my $start = Time::HiRes::gettimeofday();
my $resp  = LWP::Simple::getstore( $url, $tmpFile->filename());
my $end   = Time::HiRes::gettimeofday();

if ( LWP::Simple::is_success($resp) ) {
    my $size = stat($tmpFile->filename())->size();
    my $sizeInBit = $size * 8;
    my $time = $end - $start;
    my $bps = int( $sizeInBit / $time );
    my $netMod = EBox::Global->modInstance('network');
    $netMod->gatherReportInfo($bps);
}
