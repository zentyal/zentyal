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

package EBox::CA::TestStub;

# Description: Test stub for CA module used by OpenVPN
use strict;
use warnings;

use EBox::CA;
use Test::MockObject;
use EBox::Gettext;
use EBox;

# Method: fake
#
#       Fakes the CA module
sub fake
  {
    Test::MockObject->fake_module('EBox::CA',
				  _create             => \&_create,
				  isCreated           => \&isCreated,
				  createCA            => \&createCA,
				  revokeCACertificate => \&revokeCACertificate,
				  issueCACertificate  => \&issueCACertificate,
				  renewCACertificate  => \&renewCACertificate,
				  CAPublicKey         => \&CAPublicKey,
				  issueCertificate    => \&issueCertificate,
				  revokeCertificate   => \&revokeCertificate,
				  listCertificates    => \&listCertificates,
				  getKeys             => \&getKeys,
				  renewCertificate    => \&renewCertificate,
				  currentCACertificateState => \&currentCACertificateState,
				  destroyCA           => \&destroyCA,
				  setInitialState     => \&setInitialState
				  );
  }

# Method: unfake
#
#       Returns real CA module to reality
#
sub unfake
  {
  delete $INC{'EBox/CA.pm'};
  eval 'use EBox::CA';
  $@ and die "Error reloading EBox::CA :  $@";
}

# Method: _create
#
#       Fake CA::_create constructor
#
# Returns:
#
#       A mocked EBox::CA object
sub _create {

  my $class = shift;
  my $self = {};

  bless($self, $class);

  # Certs is a hash with the following elements
  # ca -> metadata CA cert
  # other certs metadata indexed by serial number
  # Each metadata is comprised:
  # state -> 'V', 'R' or 'E'
  # dn    -> EBox::CA::DN
  # expiryDate  -> expiration date
  # revokeDate  -> revokation date
  # reason -> if revoked, a reason
  # path   -> faked path
  # serial -> a serial number
  # keys -> [publicKeyPath, privateKeyPath ]
  $self->{certs} = {};
  $self->{created} = 0;

  return $self;

}

# Method: destroyCA
#
#         Destroy current structure from a CA
#
sub destroyCA
  {

    my ($self) = @_;

    # Destroy everything created -> not created and no certificates
    $self->{certs} = {};
    $self->{created} = 0;

    return 1;

  }

# Method: isCreated
#
#       Fake CA::isCreated method
#
sub isCreated
  {
    my ($self) = @_;

    return $self->{created};
  }

# Method: createCA
#
#       Fake CA::createCA method
#
# Parameters:
#
#       countryName  - country name {2 letter code} (eg, ES) (Optional)
#       stateName     - state or province name (eg, Aragon) (Optional)
#       localityName  - locality name (eg, Zaragoza) (Optional)
#       orgName       - organization name (eg, company name)
#       orgNameUnit  - organizational unit name (eg, section name) (Optional)
#       commonName    - common name from the CA (Optional)
#       caKeyPassword - passphrase for generating keys (*NOT WORKING*)
#       days         - expire day of self signed certificate (Optional)
#
# Returns:
#
#      1 - if everything is newly created
#      2 - if the CA certificate already exists
#
# Exceptions:
#
#      EBox::Exceptions::DataMissing - if any required parameter is missing

sub createCA
  {
    my ($self, %args) = @_;

    throw EBox::Exceptions::DataMissing(data => __('Organization Name'))
      unless defined( $args{orgName} );

    # Set CA created
    if ($self->{created}) {
      return 2;
    }
    $self->{created} = 1;

    $args{commonName} = "foo" unless ( $args{commonName} );
    # Setting CA certificate metadata
    $self->{certs}->{ca} = {};
    $self->{certs}->{ca}->{dn} = EBox::CA::DN->new ( countryName => $args{countryName},
						     stateName   => $args{stateName},
						     localityName    => $args{localityName},
						     organizationName => $args{orgName},
						     organizationNameUnit => $args{orgNameUnit},
						     commonName  => $args{commonName});
    $self->{certs}->{ca}->{state} = 'V';

    my $days = $args{days};
    $days = 30 unless ($days);

    $self->{certs}->{ca}->{expiryDate} = Date::Calc::Object->now() + [0, 0, $days, 0, 0, 0];
    $self->{certs}->{ca}->{serial} = $self->_createSerial();
    $self->{certs}->{ca}->{path} = "ca.cert";
    # Set keys
    $self->{certs}->{ca}->{keys} = [ "capubkey.pem", "caprivkey.pem" ];

    return 1;

  }

# Method: revokeCACertificate
#
#       Fake CA::revokeCACertificate method
#
# Parameters:
#
#       reason - the reason to revoke the certificate. It can be:
#                unspecified, keyCompromise, CACompromise,
#                affiliationChanged, superseeded, cessationOfOperation
#                or certificationHold (Optional)
#       caKeyPassword - the CA passphrase (*NOT WORKING*)
#       force         - Force the revokation (*NOT WORKING*)
#
# Returns:
#
#       undef if OK
#

sub revokeCACertificate
  {

    my ($self, %args) = @_;

    $self->{certs}->{ca}->{state} = 'R';
    $self->{certs}->{ca}->{reason} = $args{reason};
    foreach my $key (keys %{$self->{certs}}) {
      $self->{certs}->{$key}->{state} = 'R';
      $self->{certs}->{$key}->{reason} = "cessationOfOperation";
      $self->{certs}->{$key}->{revokeDate} = Date::Calc::Object->now();
    }

    return undef;

  }

# Method: issueCACertificate
#
#       Fake CA::issueCACertificate method
#
# Parameters:
#
#       commonName - the CA common name (Optional)
#       countryName - country name {2 letter code} (eg, ES) (Optional)
#       stateName - state or province name (eg, Zaragoza) (Optional)
#       localityName - locality name (eg, Zaragoza) (Optional)
#
#       orgName - organization name (eg, company)
#
#       orgNameUnit - organizational unit name (eg, section)
#                     (Optional)
#       days - days to hold the same certificate (Optional)
#       caKeyPassword - key passpharse for CA (*NOT WORKING*)
#       genPair - if you want to generate a new key pair (*NOT WORKING*)
#
# Returns:
#
#      the new certificate file path
#
# Exceptions:
#
#      DataMissing - if any required parameter is missing
sub issueCACertificate
  {

    my ($self, %args) = @_;

    throw EBox::Exceptions::DataMissing(data => __('Organization Name'))
      unless defined( $args{orgName} );

    if ($self->{certs}->{ca}->{state} eq 'V') {
      throw EBox::Exceptions::External(
	 __('The CA certificates should be revoked  or has expired before issuing a new certificate'));
    }

    # Copy revoked if exists
    my $oldSerial = $self->{certs}->{ca}->{serial};
    if ($oldSerial) {
      $self->{certs}->{$oldSerial}->{serial} = $oldSerial;
      $self->{certs}->{$oldSerial}->{dn} = $self->{certs}->{ca}->{dn}->copy();
      $self->{certs}->{$oldSerial}->{state} = $self->{certs}->{ca}->{state};
      $self->{certs}->{$oldSerial}->{revokeDate} = $self->{certs}->{ca}->{revokeDate};
      $self->{certs}->{$oldSerial}->{path} = $self->{certs}->{ca}->{path};
      $self->{certs}->{$oldSerial}->{keys} = $self->{certs}->{ca}->{keys};
    }

    # Define the distinguished name -> default values in configuration file
    $args{commonName} = "foo" unless ( $args{commonName} );
    $self->{certs}->{ca}->{dn} = EBox::CA::DN->new ( countryName          => $args{countryName},
				      stateName            => $args{stateName},
				      localityName         => $args{localityName},
				      organizationName     => $args{orgName},
				      organizationNameUnit => $args{orgNameUnit},
				      commonName           => $args{commonName});

    my $days = $args{days};
    $days = 30 unless ($args{days});

    $self->{certs}->{ca}->{state} = 'V';
    $self->{certs}->{ca}->{expiryDate} = Date::Calc::Object->now() + [0, 0, $days, 0, 0, 0];;
    $self->{certs}->{ca}->{serial} = $self->_createSerial();
    $self->{certs}->{ca}->{path} = "ca.cert";
    # Set keys
    $self->{certs}->{ca}->{keys} = [ "capubkey.pem", "caprivkey.pem" ];

    return $self->{certs}->{ca}->{path};

  }

# Method: renewCACertificate
#
#       Fake CA::renewCACertificate
#
# Parameters:
#
#       commonName - the CA common name (Optional)
#       countryName - country name {2 letter code} (eg, ES) (Optional)
#       stateName - state or province name (eg, Zaragoza) (Optional)
#       localityName - locality name (eg, Zaragoza) (Optional)
#
#       orgName - organization name (eg, company) (Optional)
#
#       orgNameUnit - organizational unit name (eg, section)
#                     (Optional)
#       days - days to hold the same certificate (Optional)
#       caKeyPassword - key passpharse for CA (*NOT WORKING*)
#
# Returns:
#
#       the new certificate file path or undef if any error happened
#
# Exceptions:
#
#      DataMissing - if no caKeyPassword is given
#

sub renewCACertificate
  {

    my ($self, %args) = @_;

    $self->{certs}->{$self->{certs}->{ca}->{serial}} = {};
    $self->{certs}->{$self->{certs}->{ca}->{serial}}->{state} = 'R';
    $self->{certs}->{$self->{certs}->{ca}->{serial}}->{revokeDate} = Date::Calc::Object->now();
    $self->{certs}->{$self->{certs}->{ca}->{serial}}->{dn} = $self->{certs}->{ca}->{dn}->copy();
    $self->{certs}->{$self->{certs}->{ca}->{serial}}->{reason} = 'superseded';
    $self->{certs}->{$self->{certs}->{ca}->{serial}}->{path} = $self->{certs}->{ca}->{serial} . ".cert";
    $self->{certs}->{$self->{certs}->{ca}->{serial}}->{serial} = $self->{certs}->{ca}->{serial};
    $self->{certs}->{$self->{certs}->{ca}->{serial}}->{keys} = [ $self->{certs}->{ca}->{serial} . "-pubkey.pem",
								 $self->{certs}->{ca}->{serial} . "-privkey.pem" ];

    $self->{certs}->{ca}->{state} = 'V';
    $self->{certs}->{ca}->{dn} = EBox::CA::DN->new ( countryName => $args{countryName},
						     stateName   => $args{stateName},
						     localityName    => $args{localityName},
						     organizationName => $args{orgName},
						     organizationNameUnit => $args{orgNameUnit},
						     commonName  => $self->{certs}->{ca}->{dn}->attribute('commonName'));

    my $days = $args{days};
    $days = 30 unless ($args{days});

    $self->{certs}->{ca}->{expiryDate} = Date::Calc::Object->now() + [0, 0, $days, 0, 0, 0];
    $self->{certs}->{ca}->{serial} = $self->_createSerial();

    foreach my $key (keys %{$self->{certs}}) {
      my $cert = $self->{certs}->{$key};
      if ($cert->{state} eq 'V' and
	 $cert->{expiryDate} > $self->{certs}->{ca}->{expiryDate} ) {
	# Renew the certificate to the CA certificate
	$self->renewCertificate( commonName => $cert->{dn}->attribute('commonName'),
			         endDate    => $self->{certs}->{ca}->{expiryDate}
			       );
      }
    }

    return $self->{certs}->{ca}->{path};

  }

# Method: CAPublicKey
#
#       Fake EBox::CA::CAPublicKey method
#
# Parameters:
#
#       caKeyPassword - the passphrase to access to private key
#       (*NOT WORKING*)
#
# Returns:
#
#       Path to the file which contains the CA Public Key in
#       PEM format or undef if it was not possible to create
#
sub CAPublicKey
  {

  my ($self, $caKeyPassword) = @_;

  return $self->{certs}->{ca}->{keys}[0];

}


# Method: issueCertificate 
#
#       Fake CA::issueCertificate method
#
# Parameters:
#
#       countryName - country name {2 letter code} (eg, ES) (Optional)
#       stateName - state or province name (eg, Zaragoza) (Optional)
#       localityName - locality name (eg, Zaragoza) (Optional)
#
#       orgName - organization name (eg, company) (Optional)
#
#       orgNameUnit - organizational unit name (eg, section)
#                     (Optional)
#
#       commonName - common name from the organization
#       days - expiration days of certificate (Optional)
#              Only valid if endDate is not present
#       endDate - expiration date Date::Calc::Object (Optional)
#
#       caKeyPassword - passphrase for CA to sign (*NOT WORKING*)
#       privateKeyFile - path to the private key file if there is already
#                        a private key file in the CA (Optional)
#
#       requestFile - path to save the new certificate request
#                    (*NOT WORKING*) 
#       certFile - path to store the new certificate file (*NOT WORKING*)
#
# Returns:
#
#      undef if no problem has happened
#
# Exceptions:
#
# External - if the expiration date from certificate to issue is later than CA
#            certificate expiration date (*NOT WORKING*)
#            if any error happens in signing request process (*NOT WORKING*)
#
# DataMissing - if any required parameter is missing
#

sub issueCertificate
  {

    my ($self, %args) = @_;

    # Treat arguments
    throw EBox::Exceptions::DataMissing(data => __('Common Name'))
      unless defined( $args{commonName} );

    my $serial = $self->_createSerial();

    my $days;

    if (not defined($args{endDate})) {
      $days = $args{days};
      $days = 30 unless ($args{days});
      $self->{certs}->{ca}->{expiryDate} = Date::Calc::Object->now() + [0, 0, $days, 0, 0, 0];
    }

    $self->{certs}->{ca}->{expiryDate} = $args{endDate} if ($args{endDate});
    $self->{certs}->{$serial}->{path} = $serial . ".cert";

    # Define the distinguished name
    # We take the default values from CA dn
    my $dn = $self->{certs}->{ca}->{dn}->copy();
    $dn->attribute("countryName", $args{countryName})
      if (defined($args{countryName}));
    $dn->attribute("stateName", $args{stateName})
      if (defined($args{stateName}));
    $dn->attribute("localityName", $args{localityName})
      if (defined($args{localityName}));
    $dn->attribute("orgName", $args{orgName})
      if (defined($args{orgName}));
    $dn->attribute("orgNameUnit", $args{orgNameUnit})
      if (defined($args{orgNameUnit}));
    $dn->attribute("commonName", $args{commonName})
      if (defined($args{commonName}));

    $self->{certs}->{$serial}->{state} = 'V';
    $self->{certs}->{$serial}->{dn} = $dn;
    $self->{certs}->{$serial}->{serial} = $serial;

    # Setting keys
    my $privKeyPath = $args{privateKeyFile};
    $privKeyPath = $serial . "-privkey.pem";
    $self->{certs}->{$serial}->{keys} = [ $serial . "-pubkey.pem",
					  $privKeyPath ];

  }

# Method: revokeCertificate
#
#       Fake CA::revokeCertificate method
#
# Parameters:
#
#       commonName - the common name with the certificate to revoke
#       reason - the reason to revoke the certificate. It can be:
#                unspecified, keyCompromise, CACompromise,
#                affiliationChanged, superseeded, cessationOfOperation
#                or certificationHold (Optional)
#       caKeyPassword - the CA passpharse (*NOT WORKING*)
#       certFile - the Certificate to revoke (*NOT WORKING*)
#       force    - Force the revokation (*NOT WORKING*)
#
# Returns:
#
#       undef if OK
#
# Exceptions:
#
#      External - if the certificate does NOT exist
#                 if the reason is NOT a standard one
#                 if any error occurred when revokation is done
#                 if any error occurred when creating the CRL is done
#      DataMissing - if any required parameter is missing
#
sub revokeCertificate
  {

  my ($self, %args) = @_;
  my $commonName = $args{commonName};
  my $reason = $args{reason};

  throw EBox::Exceptions::DataMissing(data => __('Common Name') )
    unless defined($commonName);

  # Find the cert
  my $cert;
  foreach my $key (keys %{$self->{certs}}) {
    if ($self->{certs}->{$key}->{dn}->attribute('commonName') eq $commonName) {
      $cert = $self->{certs}->{$key};
    }
  }

  if (not $cert) {
    throw EBox::Exceptions::External("not certificate found");
  }

  $cert->{state} = 'R';
  $cert->{reason} = $reason;

  }

# Method: listCertificates
#
#       Fake CA::listCertificates method
#
# Parameters:
#
#       state - 'R', 'V' or 'E' in order to show only revoked, valid
#               or expired certificates. All are included if not set this
#               attribute (Optional)
#
#       excludeCA - boolean indicating whether the valid CA certificate
#                   should be excluded in the response (Optional)
#
# Returns:
#
#       A reference to an array containing hashes which have the following
#       elements
#
#       - dn         - an <EBox::CA::DN> object
#       - state      - 'V' from Valid, 'R' from Revoked or 'E' from Expired
#       - expiryDate - the expiry date in a <Calc::Date::Object> if state valid
#
#       - revokeDate - the revocation date in a Date hash if state is
#                    revoked
#       - reason     - reason to revoke if state is revoked
#       - isCACert   - boolean indicating that it is the valid CA certificate
#       - path       - certificate path
#       - serialNumber  - serial number within CA
#
sub listCertificates
  {

    my ($self, %args) = @_;

    # Getting the arguments
    my $state = $args{'state'};
    my $excludeCA = $args{'excludeCA'};
    # Check parameter state is correct (R, V or E)
    if (defined($state) and $state !~ m/[RVE]/ ) {
      throw EBox::Exceptions::Internal("State should be R, V or E");
    }

    # Convert a hash to an array
    my @listCerts;
    foreach my $key (keys %{$self->{certs}}) {
      my %element;
      my $cert = $self->{certs}->{$key};
      $element{'state'} = $cert->{state};
      $element{'dn'} = $cert->{dn};
      $element{'serialNumber'} = $cert->{serial};
      $element{'path'} = $cert->{path};

      if ($element{'state'} eq 'V') {
	$element{'expiryDate'} = $cert->{expiryDate};
	$element{'isCACert'} = $key eq 'ca';
      } else {
	$element{'revokeDate'} = $cert->{revokeDate};
	$element{'reason'} = $cert->{reason};
      }

      push (@listCerts, \%element);

    }

    # Setting the filters
    if ( defined($state) ) {
      # Filter according to state
      @listCerts = grep { $_->{state} eq $state } @listCerts;
    }
    if ( $excludeCA ) {
      # Filter the valid CA certificate
      @listCerts = grep { not $_->{isCACert} } @listCerts;
    }

    # Sort the array to have CA certs first (put latest first)
    my @sortedOut = sort { $b->{state} cmp $a->{state} } @listCerts;

    return \@sortedOut;

  }

# Method: getKeys
#
#       Fake EBox::CA::getKeys method
#
# Parameters:
#
#       commonName - the common name to identify the key
#
# Returns:
#
#       a reference to a hash containing the public and private key file
#       paths (*privateKey* and *publicKey*) stored in _PEM_ format
#
# Exceptions:
#
#      External - if the keys do NOT exist
#      DataMissing - if any required parameter is missing
#
sub getKeys
  {
    my ($self, $commonName) = @_;

    throw EBox::Exceptions::DataMissing(data => __("Common Name"))
      unless defined ($commonName);

    my %keys;

    my ($cert) = grep { $_->{dn}->attribute('commonName') eq $commonName }
      values %{$self->{certs}};

    if ($cert) {
      $keys{publicKey} = $cert->{keys}[0];
      $keys{privateKey} = $cert->{keys}[1];
    } else {
      throw EBox::Exceptions::External(__x("The user {commonName} does NOT exist",
					   commonName => $commonName))
    }

    return \%keys;

  }

# Method: renewCertificate
#
#       Fake CA::renewCertificate method
#
# Parameters:
#
#       commonName - the common name from the user.
#
#       countryName - country name {2 letter code} (eg, ES) (Optional)
#       stateName - state or province name (eg, Zaragoza) (Optional)
#       localityName - locality name (eg, Zaragoza) (Optional)
#
#       orgName - organization name (eg, company) (Optional) 
#
#       orgNameUnit - organizational unit name (eg, section)
#                     (Optional)
#       days - days to hold the same certificate (Optional)
#              Only if enddate not appeared
#       endDate - the exact date when the cert expired (Optional)
#                 Only if days not appeared.It is a Date::Calc::Object.
#
#       caKeyPassword - key passpharse for CA (*NOT WORKING*)
#       certFile - the certificate file to renew (*NOT WORKING*)
#       reqFile  - the request certificate file which to renew (*NOT WORKING*)
#
#       privateKeyFile - the private key file (Optional)
#       keyPassword - the private key passpharse. Only necessary when
#       a new request is issued (*NOT WORKING*)
#
#       overwrite - overwrite the current certificate file. Only if
#       the certFile is passed (*NOT WORKING*)
#
# Returns:
#
#       the new certificate file path
#
# Exceptions:
#
# External - if the user does NOT exist,
#            if the CA passpharse CANNOT be located,
#            if the user passpharse is needed and it's NOT present,
#            if the expiration date for the certificate to renew is later than CA certificate expiration date
#            if the certificate to renew does NOT exist
#            if any error occurred when certificate renewal is done
# Internal - if any parameter is an unexcepted type
# DataMissing - if no CA passphrase is given to renew the certificate

sub renewCertificate
  {

    my ($self, %args) = @_;

    if (not defined($args{endDate}) ) {
      $args{days} = 365 unless defined ($args{days});
      if ( $args{days} > 11499 ) {
	$args{days} = 11499;
	# Warning -> Year 2038 Bug
	# http://www.mail-archive.com/openssl-users@openssl.org/msg45886.html
	EBox::warn(__("Days set to the maximum allowed: Year 2038 Bug"));
      }
    }

    my $userExpDay = $args{endDate};
    $userExpDay = Date::Calc::Object->now() + [0, 0, $args{days}, 0, 0, 0]
      unless ($userExpDay);

    if ( $userExpDay gt $self->{certs}->{ca}->{expiryDate} ) {
      throw EBox::Exceptions::External(__("Expiration date later than CA certificate expiration date"));
    }

    # User cert
    # Find the cert
    my ($cert) = grep { $_->{dn}->attribute('commonName') eq $args{commonName} }
      values %{$self->{certs}};

    # Check if a change in DN is needed
    my $userDN = $cert->{dn}->copy();
    my $dnFieldHasChanged = '0';
    if ( defined($args{countryName})
	 and $args{countryName} ne $userDN->attribute('countryName')) {
      $dnFieldHasChanged = "1";
      $userDN->attribute('countryName', $args{countryName});
    }
    if (defined($args{stateName}) 
	and $args{stateName} ne $userDN->attribute('stateName')) {
      $dnFieldHasChanged = "1" ;
      $userDN->attribute('stateName', $args{stateName});
    }
    if (defined($args{localityName})
	and $args{localityName} ne $userDN->attribute('localityName')) {
      $dnFieldHasChanged = "1" ;
      $userDN->attribute('localityName', $args{localityName});
    }
    if (defined($args{orgName})
	and $args{orgName} ne $userDN->attribute('orgName')) {
      $dnFieldHasChanged = "1" ;
      $userDN->attribute('orgName', $args{orgName});
    }
    if (defined($args{orgNameUnit})
	and $args{orgNameUnit} ne $userDN->attribute('orgNameUnit')) {
      $dnFieldHasChanged = "1" ;
      $userDN->attribute('orgNameUnit', $args{orgNameUnit});
    }

    $self->revokeCertificate(commonName => $userDN->attribute('commonName'),
			     reason     => "superseded");

    $self->issueCertificate(commonName     => $userDN->attribute('commonName'),
			    endDate        => $args{endDate},
			    privateKeyFile => $args{privateKeyFile});

  }

# Method: currentCACertificateState
#
#       Fake CA::currentCACertificateState method
#
# Returns:
#
#       The current CA Certificate state
#       - R - Revoked
#       - E - Expired
#       - V - Valid
#       - ! - Inexistent
#
sub currentCACertificateState
  {

    my ($self) = @_;

    my $certRef = $self->{certs}->{ca};

    if ( not defined($certRef) ) {
      return "!";
    } else {
      return $certRef->{'state'};
    }

}

# Method: setInitialState
#
#       Set a serie of certs for a CA
#
# Parameters
#
#       listCert - a list reference of hashes with cert metadata. The
#       hash should have the following elements:
#         - state       -> 'V', 'R' or 'E' (Optional)
#         - dn          -> EBox::CA::DN or an String formatted as /type0=value0/type1=value1/...
#         - expiryDate  -> EBox::Date::Object expiration date (Optional)
#         - revokeDate  -> EBox::Date::Object revokation date (Optional)
#         - reason      -> if revoked, a reason (Optional)
#         - isCACert    -> boolean indicating if it's a valid CA certificate
#                       -> Just ONE can have this attribute on (Optional)
#         - path        -> string with the certificate path (Optional)
#         - keys        -> path for keys as an array reference, first element is the public one and second one is the private one
#
sub setInitialState
  {

    my ($self, $listCerts) = @_;

    my $caCertShown = 0;
    $self->{certs} = {};

    foreach my $argCertRef (@{$listCerts}) {
      my $serial = $self->_createSerial();
      my $certRef;
      # Checking just one CA cert is given, the rest are ignored
      if (not $caCertShown and $argCertRef->{isCACert}) {
	$self->{certs}->{ca} = {};
	$certRef = $self->{certs}->{ca};
	$caCertShown = 1;
	$self->{created} = 1;
      } else {
	$self->{certs}->{$serial} = {};
	$certRef = $self->{certs}->{$serial};
      }
      # Copying all remainder data
      $certRef->{state} = 'V' unless ($argCertRef->{state});
      $certRef->{state} = $argCertRef->{state} if ($argCertRef->{state});
      if (UNIVERSAL::isa($argCertRef->{dn}, "EBox::CA::DN") ) {
	$certRef->{dn} = $argCertRef->{dn};
      } else {
	# I assume an string is passed
	$certRef->{dn} = EBox::CA::DN->parseDN($argCertRef->{dn});
      }
      if ($certRef->{state} eq 'V' or $certRef->{state} eq 'E') {
	$certRef->{expiryDate} = Date::Calc::Object->now() + [0,0,+365] unless ($argCertRef->{expiryDate});
	$certRef->{expiryDate} = $argCertRef->{expiryDate} if ($argCertRef->{expiryDate});
      } elsif ($certRef->{state} eq 'R') {
	$certRef->{revokeDate} = $argCertRef->{revokeDate} if ($argCertRef->{revokeDate});
	$certRef->{revokeDate} = Date::Calc::Object->now();
	$certRef->{reason} = $argCertRef->{reason};
      }
      $certRef->{path} = $serial . ".cert" unless ($argCertRef->{path});
      $certRef->{path} = $argCertRef->{path} if ($argCertRef->{path});
      $certRef->{serial} = $serial;
      if ($argCertRef->{keys}) {
	$certRef->{keys} = $argCertRef->{keys};
      } else {
	$certRef->{keys} = [ $serial . "-pubkey.pem",
			     $serial . "-privkey.pem" ];
      }

    }

    return;

  }

1;
