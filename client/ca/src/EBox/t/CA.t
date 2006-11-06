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

# A module to test CA module

use Test::More tests => 28;
use Test::Exception;
use Date::Calc::Object qw (:all);

diag ( 'Starting EBox::CA test' );

BEGIN {
  use_ok ( 'EBox::CA' )
    or die;
}

system('rm -r /var/lib/ebox/CA');

my $ca = EBox::CA->new();

isa_ok ( $ca , "EBox::CA");

is ( $ca->domain(), 'ebox-ca', 'is a gettext domain');

ok ( ! $ca->isCreated(), 'not created' );

throws_ok { $ca->createCA() } "EBox::Exceptions::DataMissing", "data missing error";

is ( $ca->createCA(orgName => "Warp",
		   caKeyPassword => "mama",
		   commonName => "lalala"), 1, 'creating CA' );

throws_ok { $ca->revokeCACertificate(reason => 'affiliationChanged',
				     caKeyPassword => 'papa') }
  "EBox::Exceptions::External", "error revokation with wrong password";

ok ( ! defined($ca->revokeCACertificate(reason => 'affiliationChanged',
					caKeyPassword => 'mama')),
     "revoking CA certificate");

ok ( $ca->issueCACertificate(orgName => "Warpera",
			     caKeyPassword => 'papa',
			     genPair       => 1),
     "issuing CA certificate");

ok ( $ca->renewCACertificate(localityName => 'La Juani',
			     days => 100,
			     caKeyPassword => 'papa'),
     "renewing CA certificate");

ok ( $ca->CAPublicKey, "Retrieving the CA public key");

throws_ok { $ca->issueCertificate(commonName => 'uno 1',
				 endDate => Date::Calc->new(2010, 10, 20, 00, 00, 00),
				 days => 10,
				 keyPassword => 'aaab') }
  'EBox::Exceptions::External', "issuing a certificate with later date than CA";

ok ( $ca->issueCertificate(commonName => 'uno 1',
				     endDate    => Date::Calc->new(2006, 12, 31, 23, 59, 59),
				     keyPassword => 'aaab'),
     "issuing 1st certificate");

ok ( $ca->issueCertificate(commonName => 'dos',
			   days => 15,
			   keyPassword => 'aaac')
     , "issuing 2nd certificate");

# Check a very long name

throws_ok { $ca->issueCertificate(commonName => 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
			   days => 10,
			   keyPassword => 'aaae')
	   } "EBox::Exceptions::External" ,
     "issuing a very long certificate";

throws_ok { $ca->revokeCertificate(commonName => 'tres',
				   caKeyPassword => 'papa') }
  "EBox::Exceptions::External", "revoking an unexistent certificate";

ok ( ! defined($ca->revokeCertificate(commonName => 'dos',
				      caKeyPassword => 'papa')),
     , "revoking 2nd certificate");

my $listCerts = $ca->listCertificates(cn => 'uno 1');

cmp_ok ( $#{$listCerts}, '==', 0, 'one certificate with cn="uno 1"');

$listCerts = $ca->listCertificates();

cmp_ok ( $#{$listCerts} + 1, '==', 5, 'listing certificates (revoked + valid)' );

throws_ok { $ca->renewCertificate(commonName    => 'uno 1',
			   countryName   => 'Canary Islands',
			   endDate       => Date::Calc->new(2010,5,10,00,00,00),
			   keyPassword   => 'aaab',
			   caKeyPassword => 'papa')}
	      "EBox::Exceptions::External",
     'Renewing a certificate';

throws_ok { $ca->getKeys('tres') } "EBox::Exceptions::External",
  'getting unexistent key pair';

my $keyPair = $ca->getKeys('uno 1');

cmp_ok ( scalar(keys %{$keyPair}), '==', 2, 'getting key pair');

$ca->removePrivateKey('uno 1');

$keyPair = $ca->getKeys('uno 1');

cmp_ok ( scalar(keys %{$keyPair}), '==', 1, 'getting public key');

is ( $ca->currentCACertificateState(), 'V', 'checking current CA certificate state');

ok ( ! defined($ca->revokeCACertificate(reason => 'CACompromise',
					caKeyPassword => 'papa')),
     "revoking all certificates");

is ( $ca->currentCACertificateState(), 'R', 'checking final CA certificate state');

cmp_ok( scalar(@{$ca->revokeReasons()}), '==', 7, 'revoking reasons count');

lives_ok { $ca->updateDB() } 'updating database';

