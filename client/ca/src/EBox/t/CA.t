#!/usr/bin/perl -Tw

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

# A module to test CA module

use Test::More 'no_plan';
use Test::Env;

BEGIN {
  use_ok ( 'EBox::CA' )
    or die;
}

diag ( 'Starting EBox::CA test' );

system('rm -r /var/lib/ebox/CA');

my $ca = EBox::CA->new();

isa_ok ( $ca, "EBox::CA" );

is ( $ca->domain(), 'ebox-ca', 'is a gettext domain');

ok ( not $ca->isCreated(), 'not created' );

is ( $ca->createCA(), 1, 'creating CA' );

ok ( not defined($ca->revokeCACert(reason => 'affiliationChanged',
				   caKeyPassword => 'papa')),
     "revoking CA certificate");

ok ( $ca->issueCACertificate(caKeyPassword => 'mama',
			     genPair       => 1),
     "issuing CA certificate");

ok ( $ca->renewCACertificate(days => 100),
     "renewing CA certificate");

