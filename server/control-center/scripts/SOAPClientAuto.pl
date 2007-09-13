#!/usr/bin/perl -w

# Copyright (C) 2007 Warp Networks S.L.
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

# A SOAP client

use warnings;
use strict;

use Data::Dumper;
use Error qw(:try);
use EBox::Exceptions;

# SSL stuff
$ENV{HTTPS_CERT_FILE} = '/var/lib/ebox-cc/CA/certs/E2C9F319DAD0C939.pem';
$ENV{HTTPS_KEY_FILE}  = '/var/lib/ebox-cc/CA/private/OpenVPN server.pem';
$ENV{HTTPS_CA_FILE} = '/var/lib/ebox-cc/CA/cacert.pem';

#$ENV{HTTPS_DEBUG} = 1;

# default ssl version
$ENV{HTTPS_VERSION} = '3';

use SOAP::Lite
  dispatch_from => [ 'EBox::SOAP::Global' ],
  uri           => 'http://ebox-platform.com/EBox/SOAP/Global',
  proxy         => 'https://192.168.45.131:44300/soap',
  on_fault => sub {
                   my ($soap, $res) = @_;
		   if ( ref $res ) {
		     # Get the exception type
		     my $excType = (keys %{$res->faultdetail()})[0];
		     # Get the hash to bless
		     my $hash_ref = $res->faultdetail()->{$excType};
		     # Substitute from __ to ::
		     $excType =~ s/__/::/g;
		     # Do the bless to have the exception object
		     bless ($hash_ref, $excType);
		     throw $hash_ref;
		   }
		   else {
		     die $soap->transport()->status() . $/;
		   }
		 }
  ;

my $globalRem = EBox::SOAP::Global->new();
print 'Get the remote object: ' . $/ . Dumper($globalRem) . $/;

print 'Is read only instance?: ' . ($globalRem->isReadOnly() ? 'true' : 'false' ) . $/;

my $mods_ref = $globalRem->modNames();
print Dumper($mods_ref);

print 'EBox module ca exists? ' . ( $globalRem->modExists('ca') ? 'true' : 'false' ). $/;

print 'Is eBox CA created? ' . $globalRem->modMethod('ca', 'isCreated') . $/;

try {
  # Launch EBox::Exceptions::DataMissing
  $globalRem->modMethod('ca', 'getCertificateMetadata');
  # Launch EBox::Exceptions::External
  $globalRem->modMethod('ca', 'revokeCertificate', (commonName => 'foobar'));
} catch EBox::Exceptions::DataMissing with {
  shift;
  my $ret_ref = shift;
  # Continue processing try block
  ${$ret_ref} = 1;
  print 'DataMissing exception caught' . $/;
} catch EBox::Exceptions::External with {
  print 'External exception caught' . $/;
};

#print 'Get certificate ' . Dumper( $globalRem->modMethod('ca', 'getCertificateMetadata') ) . $/;

#$response = $soapConn->modMethod($globalRem, 'ca', '_foo');
print 'Calling private method ' . $globalRem->modMethod('ca', '_foo') . $/;
#
#$response = $soapConn->modMethod($globalRem, 'ca', 'foobar');
#print 'Calling to an undefined method ' . $response->result() . $/;




