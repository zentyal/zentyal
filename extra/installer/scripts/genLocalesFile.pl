#!/usr/bin/perl
# Copyright (C) 2008 Warp Networks S.L.
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

#

use strict;
use warnings;

use EBox::Gettext;

use constant FILE_NAME => 'locale.gen';

my ($dstDir) = @ARGV;
if (not $dstDir) {
  $dstDir = './';
  warn "No destination dir provided using actual directory";
}


my $path= "$dstDir/" . FILE_NAME;

my $langs = EBox::Gettext::langs();

open my $FH, ">$path" or 
  die  "Cannot open $path: $!";

 my  @locales = sort keys %{ $langs };
foreach my $locale ( @locales ) {
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
