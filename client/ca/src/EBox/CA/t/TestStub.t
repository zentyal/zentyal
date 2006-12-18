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

# A module to test faked CA module

use Test::More tests => 27;
use Test::Exception;
use Date::Calc::Object qw (:all);
use Data::Dumper;
use EBox::Global;
use EBox::CA::DN;

diag ( 'Starting EBox::CA::TestStub test' );

BEGIN {
  use_ok ( 'EBox::CA::TestStub' )
    or die;
}

# Fake the module
EBox::CA::TestStub->fake();

my $ca = EBox::Global->modInstance('ca');

isa_ok ( $ca , "EBox::CA");

ok ( ! $ca->isCreated(), 'not created');

throws_ok { $ca->createCA() } 'EBox::Exceptions::DataMissing', 'data missing error';

cmp_ok ( $ca->createCA(orgName => "Warp",
		   commonName => "lalala"), 
	 '==', 1, 'creating CA' );

ok ( $ca->getCACertificateMetadata(), "getting current valid CA" );

ok ( ! defined($ca->revokeCACertificate(reason => 'affiliationChanged')),
     "revoking CA certificate");

ok ( $ca->issueCACertificate(orgName => "Warpera"),
     "issuing CA certificate");

ok ( $ca->renewCACertificate(localityName => 'La Juani',
			     days => 100),
     "renewing CA certificate");

ok ( $ca->CAPublicKey(), "getting CA public key" );

ok ( $ca->issueCertificate(commonName => 'uno 1',
			   endDate    => Date::Calc->new(2006, 12, 31, 23, 59, 59)),
     "issuing 1st certificate");

ok ( $ca->issueCertificate(commonName => 'dos',
			   days => 15), 
     "issuing 2nd certificate");

throws_ok { $ca->revokeCertificate(commonName => 'tres') } "EBox::Exceptions::External", 
     "revoking an unexistent certificate";

ok ( ! defined($ca->revokeCertificate(commonName => 'dos'))
     , "revoking 2nd certificate");

my $listCerts;

my $cert = $ca->getCertificateMetadata(cn => 'uno 1');

cmp_ok ( $cert->{dn}->attribute('commonName'), "eq", "uno 1" , 'certificate with cn="uno 1"');

$listCerts = $ca->listCertificates();

cmp_ok ( scalar(@{$listCerts}), '==', 5, 'listing certificates (revoked + valid)' );

throws_ok { $ca->renewCertificate(commonName    => 'uno 1',
				  countryName   => 'Canary Islands',
				  endDate       => Date::Calc->new(2010,5,10,00,00,00))}
	      "EBox::Exceptions::External",
		'renewing a wrong certificate';

ok ( $ca->renewCertificate(commonName  => 'uno 1',
			   countryName => 'Canary Islands',
			   days        => 12,
			   privateKeyFile => 'foo.pem'),
     'renewing a right certificate');

$listCerts = $ca->listCertificates(excludeCA => 1);

cmp_ok ( scalar(@{$listCerts}), '==', 5, 'getting all certificates apart from CA' );

# Get only the valid ones
$listCerts = $ca->listCertificates(state => 'V', excludeCA => 1);

cmp_ok ( scalar(@{$listCerts}), '==', 1, 'getting valid certificates' );

throws_ok { $ca->listCertificates(state => 'A') } "EBox::Exceptions::Internal",
  "getting certificates from an unknown state";

is ( $ca->currentCACertificateState(), 'V', 'checking current CA certificate state');

ok ( ! defined($ca->revokeCACertificate(reason => 'CACompromise')),
     "revoking all certificates");

is ( $ca->currentCACertificateState(), 'R', 'checking final CA certificate state');

cmp_ok ( $ca->getCACertificateMetadata(), '==', 0, "not getting a valid CA" );

my $list_ref = $ca->listCertificates();

# Testing SetInitialState
my $dn = EBox::CA::DN->new(organizationName     => 'foo',
			   organizationNameUnit => 'bar',
			   commonName           => 'foobar');

my $date = Date::Calc->new(2010, 10, 10, 23, 59, 59);

$ca->setInitialState ( [ { state      => 'V',
			   dn         => $dn,
			   expiryDate => $date,
			   isCACert   => 1
			 },
			 { state      => 'V',
			   dn         => $dn,
			   expiryDate => $date + [0,0,-1],
			   path       => 'foo.cert'
			 },
			 { state      => 'R',
			   dn         => $dn,
			   revokeDate => Date::Calc::Object->now(),
			   reason     => 'cessationOfOperation',
			   path       => 'bar.cert'
			 },
			 { state      => 'E',
			   dn         => '/C=ES/ST=Nation/L=Nowhere/O=ACV/CN=oaoa',
			   expiryDate => Date::Calc::Object->now()
			 },
			 { dn         => '/C=ES/ST=Nation/L=Nowhere/O=foobar/CN=aaa',
			   keys       => [ "foo-pubkey.pem", "bar-privkey.pem" ]
			 }
		       ]
		     );

cmp_ok ( scalar(@{$ca->listCertificates()}), '==', 5, 'setting initial state');

# Destroy it!
ok( $ca->destroyCA(), "destroying CA structure");

# Unfake the module
EBox::CA::TestStub->unfake();
