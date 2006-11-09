#!/usr/bin/perl -w

# Copyright (C) 2006 Warp Networks S.L.
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

# A module to test new Squid module functions

use Test::More tests => 6;

diag( 'Starting EBox::Squid test' );

BEGIN {
  use_ok ( 'EBox::Squid' )
    or die;
}

my $squid = EBox::Squid->_create();

isa_ok( $squid, 'EBox::Squid' );

# Controlling allowed
my $allowed = $squid->allowedMimeTypes();
my $oldN = scalar (@{$allowed});

print "Allowed mime types: " . @{$allowed} . $/;

my @res = grep { /application\/octet-stream/ } @{$allowed};

my $mimeType = "application/octet-stream";

push ( @{$allowed}, $mimeType );

print @{$allowed};

$squid->setAllowedMimeTypes(@{$allowed});

$allowed = $squid->allowedMimeTypes();
my $n = scalar (@{$allowed});

cmp_ok ( $n, "==", $oldN + 1, 'allowed mime type added correctly');

# Restoring old values
pop ( @{$allowed} );
$squid->setAllowedMimeTypes(@{$allowed});

# Controlling banned
my $banned = $squid->bannedMimeTypes();
$oldN = scalar (@{$banned});

print "Banned mime types: " . @{$banned} . $/;
print @{$banned};

@res = grep { /image\/pipeg/ } @{$banned};

$mimeType = "image/pipeg";

push ( @{$banned}, $mimeType );

$squid->setBannedMimeTypes(@{$banned});

$banned = $squid->bannedMimeTypes();
$n = scalar (@{$banned});

cmp_ok ( $n, "==", $oldN + 1, 'banned mime type added correctly');

# Restoring old values
pop ( @{$banned} );
$squid->setBannedMimeTypes(@{$banned});

# Compare with hashed
my $hashed = $squid->hashedMimeTypes();
my ($cAllowed, $cBanned ) = (0, 0);
foreach my $value (values %{$hashed}) {
  # Do you like perl conditional commands? XD
  $cAllowed++ if ($value);
  $cBanned++  unless ($value);
}

cmp_ok ( $cAllowed, "==", scalar(@{$allowed}), '');
cmp_ok ( $cBanned, "==", scalar(@{$banned}), '');
