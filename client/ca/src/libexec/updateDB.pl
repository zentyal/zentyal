#!/usr/bin/perl

# Copyright (C) 2009 eBox Technologies S.L.
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

# Description:
#
#  This script is intended to update certificate DB to change expired
#  certificates from valid to expired state

use EBox;
use EBox::Global;

use Getopt::Long;
use Pod::Usage;

my $usage = 0;
my $correct = GetOptions(
    "usage|help" => \$usage,
   );

if ( $usage or (not $correct)) {
    pod2usage(1);
}

EBox::init();
my $ca = EBox::Global->modInstance('ca');

if ( $ca->isCreated() ) {
    $ca->updateDB();
}

1;

__END__

=head1 NAME

updateDB.pl - Update certificate DB

=head1 SYNOPSIS

updateDB.pl [--usage|help]

 Options:
   -- usage|help  Print this help and exit

=cut

