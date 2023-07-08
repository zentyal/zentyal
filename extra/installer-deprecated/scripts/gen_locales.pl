#!/usr/bin/perl

# Copyright (C) 2008-2013 Zentyal S.L.
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

use constant FILE_NAME => 'locale.gen';

my ($dstDir) = @ARGV;
if (not $dstDir) {
    $dstDir = './';
    warn "No destination dir provided using actual directory";
}

my $path = "$dstDir/" . FILE_NAME;

open my $FH, ">$path" or
die  "Cannot open $path: $!";

my @locales = qw(
    an_ES.UTF-8
    bn_BD.UTF-8
    bg_BG.UTF-8
    es_ES.UTF-8
    et_EE.UTF-8
    ca_ES.UTF-8
    cs_CZ.UTF-8
    da_DK.UTF-8
    de_DE.UTF-8
    el_GR.UTF-8
    en_US.UTF-8
    eu_ES.UTF-8
    fa_IR.UTF-8
    fr_FR.UTF-8
    gl_ES.UTF-8
    he_HE.UTF-8
    hu_HU.UTF-8
    it_IT.UTF-8
    ja_JP.UTF-8
    lt_LT.UTF-8
    nb_NO.UTF-8
    nl_BE.UTF-8
    pl_PL.UTF-8
    pt_BR.UTF-8
    pt_PT.UTF-8
    ro_RO.UTF-8
    ru_RU.UTF-8
    sl_SL.UTF-8
    sv_SE.UTF-8
    th_TH.UTF-8
    tr_TR.UTF-8
    uk_UA.UTF-8
    vi_VI.UTF-8
    yo_NG.UTF-8
    zh_CN.UTF-8
    zh_TW.UTF-8
);

foreach my $locale (@locales) {
    if ($locale eq 'C') {
        # standard locale 'C' dont need to be generated so we skip it
        next;
    }

    my $encoding = '';
    if ($locale =~  m/UTF-8/) {
        $encoding = ' UTF-8';
    }

    print $FH $locale, $encoding, "\n" or
        die $!;
}

close $FH or
die "Cannot close $path: $!";

1;
