#!/usr/bin/perl -w

# Copyright (C) 2011-2012 Zentyal S.L.
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
use LWP::UserAgent;
use Time::HiRes;

EBox::init();

my $url = 'http://download.thinkbroadband.com/5MB.zip';

my $ua = new LWP::UserAgent();
$ua->agent("Mozilla/5.0");
my $tmpFile = new File::Temp();
my $start = Time::HiRes::gettimeofday();
my $resp  = $ua->request(new HTTP::Request(GET => $url),
                         $tmpFile->filename());
my $end   = Time::HiRes::gettimeofday();

if ($resp->is_success()) {
    my $size = stat($tmpFile->filename())->size();
    my $sizeInBit = $size * 8;
    my $time = $end - $start;
    my $bps = int($sizeInBit / $time);
    my $netMod = EBox::Global->modInstance('network');
    $netMod->gatherReportInfo($bps);
}
