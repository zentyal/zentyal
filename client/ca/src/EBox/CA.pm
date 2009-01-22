# Copyright (C) 2006-2007 Warp Networks S.L.
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

package EBox::CA;

use strict;
use warnings;

####################################
# Dependencies:
# File::Slurp package
# Perl6::Junction package
# Date::Calc::Object  (which has as a dependency Carp::Clan and Bit::Vector)
# File::Copy::Recursive
####################################
use File::Slurp;
use Perl6::Junction qw(any);
use Date::Calc::Object qw(:all);
use File::Copy::Recursive qw(dircopy fcopy);

use base 'EBox::GConfModule';

use EBox::CA::DN;
use EBox::Gettext;
use EBox::Config;
#use EBox::LogAdmin qw ( :all );
use EBox::Menu::Item;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataInUse;
use EBox;

use constant TEMPDIR     => EBox::Config->tmp(); # "/tmp/";
use constant OPENSSLPATH => "/usr/bin/openssl";

use constant CATOPDIR => EBox::Config->home() . "CA/";

use constant SSLCONFFILE => EBox::Config->conf() . "openssl.cnf";
# CATOPDIR . "../openssl.cnf";

# All paths related to CATOPDIR
use constant REQDIR      => CATOPDIR . "reqs/";
use constant PRIVDIR     => CATOPDIR . "private/";
use constant CRLDIR      => CATOPDIR . "crl/";
use constant NEWCERTSDIR => CATOPDIR . "newcerts/";
use constant CERTSDIR    => CATOPDIR . "certs/";
# Place to put the public keys
use constant KEYSDIR      => CATOPDIR . "keys/";
use constant CAREQ        => REQDIR   . "careq.pem";
use constant CACERT       => CATOPDIR . "cacert.pem";
use constant INDEXFILE    => CATOPDIR . "index.txt";
use constant CRLNOFILE    => CATOPDIR . "crlnumber";
use constant SERIALNOFILE => CATOPDIR . "serial";
use constant LASTESTCRL   => CRLDIR   . "latest.pem";

# Keys from CA
use constant CAPRIVKEY   => PRIVDIR . "cakey.pem";
use constant CAPUBKEY    => KEYSDIR . "capubkey.pem";

# Directory mode to allow only owner and readable from others
use constant DIRMODE     => 00705;
use constant PRIVATEDIRMODE     => 00700;

# Use Certification Version 3
use constant EXTENSIONS_V3 => "1";

# Default values for some fields
use constant CA_CN_DEF   => "Certification Authority Certificate";

# Index for every field (split with tabs) within the index.txt file
use constant STATE_IDX           => 0;
use constant EXPIRE_DATE_IDX     => 1;
use constant REV_DATE_REASON_IDX => 2;
use constant SERIAL_IDX          => 3;
use constant FILE_IDX            => 4;
use constant SUBJECT_IDX         => 5;

# Catch the openssl executable
my $openssl;
if ( defined $ENV{OPENSSL} ) {
  $openssl = $ENV{OPENSSL};
} else {
  $openssl = OPENSSLPATH;
  $ENV{OPENSSL} = $openssl;
}

# Group: Public methods

# Constructor: _create
#
#      Create a new EBox::CA object
#
# Returns:
#
#      A recent EBox::CA object
sub _create
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'ca',
					  domain => 'ebox-ca',
#					  title => __n('Certification Authority'),
					  @_);

	bless($self, $class);

	# Setting admin actions
#	$self->_setLogAdminActions();

	# OpenSSL environment stuff
	$self->{tmpDir} = TEMPDIR;
	$self->{shell} = OPENSSLPATH;
	# The CA DN
	$self->{dn} = $self->_obtain(CACERT, 'DN');
	# Reasons to revoke
	$self->{reasons} = ["unspecified",
			    "keyCompromise",
			    "CACompromise",
			    "affiliationChanged",
			    "superseded",
			    "cessationOfOperation",
			    "certificateHold",
			    "removeFromCRL"];
	# Expiration CA certificate
	$self->{caExpirationDate} = $self->_obtain(CACERT, 'endDate');

	# Set a maximum to establish the certificate expiration
	# Related to Year 2038 bug
	$self->{maxDays} = $self->_maxDays();

	return $self;
}

# Method: domain
#
#       Return the gettext domain
#
# Returns:
#
#       string - the gettext domain

sub domain
  {
    return 'ebox-ca';
  }

# Method: isCreated
#
#       Check whether the Certification Infrastructure has been
#       created or not
#
# Returns:
#
#       boolean - True, if the Certification Infrastructure has been
#       created. Undef, otherwise.
#

sub isCreated
  {
    my ($self, $name) = @_;

    my $retValue = ((-d CATOPDIR) and (-f CACERT) and (-f CAPRIVKEY)
      and (-f CAPUBKEY));

    return $retValue;

  }

# Method: createCA
#
#       Create a Certification Authority with a self-signed certificate
#       and if it not setup, create the directory hierarchy for the CA
#
# Parameters:
#
#       countryName  - country name {2 letter code} (eg, ES) *(Optional)*
#       stateName     - state or province name (eg, Aragon) *(Optional)*
#       localityName  - locality name (eg, Zaragoza) *(Optional)*
#       orgName       - organization name (eg, company name)
#       orgNameUnit  - organizational unit name (eg, section name) *(Optional)*
#       commonName    - common name from the CA *(Optional)*
#       caKeyPassword - passphrase for generating keys *(Optional)*
#       days         - expire day of self signed certificate *(Optional)*
#
#       - Named parameters
#
# Returns:
#
#      1 - if everything is newly created
#      2 - if the CA certificate already exists
#
# Exceptions:
#
#      <EBox::Exceptions::DataMissing> - if any required parameter is
#      missing

sub createCA {

  my ($self, %args) = @_;

  throw EBox::Exceptions::DataMissing(data => __('Organization Name'))
    unless defined( $args{orgName} );

  if ( ! -d CATOPDIR ) {
    # Create the directory hierchary
    mkdir (CATOPDIR, DIRMODE);
    # Let's assume the subdirectories have the same name
    mkdir (CERTSDIR, DIRMODE);
    mkdir (CRLDIR, DIRMODE);
    mkdir (NEWCERTSDIR, DIRMODE);
    mkdir (KEYSDIR, DIRMODE);
    mkdir (PRIVDIR, PRIVATEDIRMODE);
    mkdir (REQDIR, DIRMODE);
    # Create index and crl number
    open ( my $OUT, ">" . INDEXFILE);
    close ($OUT);
    open ( $OUT, ">" . CRLNOFILE);
    print $OUT "01\n";
    close ($OUT);
  }

  # Save the current CA password for private key (It can be undef)
  $self->{caKeyPassword} = $args{caKeyPassword};

  return 2 if (-f CACERT);

  # Define the distinguished name -> default values in configuration file
  $args{commonName} = CA_CN_DEF unless ( $args{commonName} );
  $self->{dn} = EBox::CA::DN->new ( countryName => $args{countryName},
				    stateName   => $args{stateName},
				    localityName    => $args{localityName},
				    organizationName => $args{orgName},
				    organizationNameUnit => $args{orgNameUnit},
				    commonName  => $args{commonName});

  # Make the CA certificate
  $args{days} = 3650 unless ( defined ($args{days}) );
  if ( $args{days} > $self->{maxDays} ) {
    $args{days} = $self->{maxDays};
    # Warning -> Year 2038 Bug
    # http://www.mail-archive.com/openssl-users@openssl.org/msg45886.html
    EBox::warn(__x("Days set to the maximum allowed {days}: Year 2038 Bug",
		   days => $self->{maxDays}));
  }


  # To create the request the distinguished name is needed
  my $output = $self->_createRequest(reqFile     => CAREQ,
				     genKey      => 1,
				     privKey     => CAPRIVKEY,
				     keyPassword => $self->{caKeyPassword},
				     dn          => $self->{dn},
				     needPass    => defined($self->{caKeyPassword})
				    );

  if ($output) {
    throw EBox::Exceptions::External($self->_filterErrorFromOpenSSL($output));
  }

  # Sign the selfsign certificate
# $self->_signRequest(userReqFile  => CAREQ,
#		      days         => $args{days},
#		      userCertFile => CACERT,
#		      selfsigned   => "1");

  # OpenSSL v. 0.9.7
  # We should create the serial
  my $serialNumber = $self->_createSerial();

  $self->_signSelfSignRequest(userReqFile  => CAREQ,
			      days         => $args{days},
			      userCertFile => CACERT,
			      serialNumber => $serialNumber,
			      keyFile      => CAPRIVKEY);

  # OpenSSL v. 0.9.7 Bugs -> Resolved in openssl ca utility later on
  # OpenSSL v. 0.9.7 -> Write down in index.txt
  $self->_putInIndex(dn           => $self->{dn},
		     certFile     => CACERT,
		     serialNumber => $serialNumber);
  # Create the serial file
  if ( ! -f SERIALNOFILE ) {
    $self->_writeDownNextSerial(CACERT);
  }
  # Create the serial attribute file
  if ( ! (-f INDEXFILE . ".attr") ) {
    $self->_writeDownIndexAttr(INDEXFILE . ".attr");
  }

  # Generate the public key file
  $self->_getPubKey(CAPRIVKEY,
		    CAPUBKEY,
		    $self->{caKeyPassword});

  # Set the CA certificate expiration date
  $self->{caExpirationDate} = $self->_obtain(CACERT, 'endDate');

  # Logging the action
#  logAdminNow($self->name, "createCA",
#	      "orgName=". $self->{dn}->attribute('orgName') . ",days=" . $args{days}
#	      );

  #unlink (CAREQ);
  $self->_setPasswordRequired(defined($self->{caKeyPassword}));

  return 1;

}

# Method: destroyCA
#
#       Destroys CA structure (the opposite operation to <createCA> method)
#
# Returns:
#
#      1 - if everything is completely destroys
#      2 - nothing to destroy
#
# Exceptions:
#
#      EBox::Exceptions::External - if the remove operation cannot complete
#
sub destroyCA
  {

    my ($self, $caKeyPassword) = @_;

    if (not $self->isCreated()) {
      return 2;
    }

    # Using system rm -rf to delete CA directory
    if ( system('rm -rf ' . CATOPDIR) != 0 )  {
      throw EBox::Exceptions::External(__("The remove operation cannot be finished. Reason: ")
				       . $!);
    }

    # Logging the action
#    logAdminNow($self->name, "destroyCA",
#		"orgName=". $self->{dn}->attribute('orgName')
#	       );

    # Set internal attribute to undefined
    $self->{dn} = undef;
    $self->{caExpirationDate} = undef;
    $self->{caKeyPassword} = undef;

    return 1;

  }

# Method: passwordRequired
#
#       Check if the password is required to sign the certificates
#       within this Certification Authority
#
# Returns:
#
#       boolean - true if pass is required, false otherwise
#
sub passwordRequired
  {

      my ($self) = @_;

      my $caState = $self->currentCACertificateState();

      # Password could be required only if a CA has been created
      return undef unless ($caState eq 'V');

      return $self->get_bool('pass_required');

  }

# Method: revokeCACertificate
#
#       Revoke the self-signed CA certificate and subsequently all the
#       issued certificates
#
# Parameters:
#
#       reason - the reason to revoke the certificate. It can be:
#                unspecified, keyCompromise, CACompromise,
#                affiliationChanged, superseeded, cessationOfOperation
#                or certificationHold (Optional)
#       caKeyPassword - the CA passpharse (Optional)
#       force  - Force the revokation (Optional)
#
# Returns:
#
#       undef if OK
#
# Exceptions:
#
#       EBox::Exceptions::DataInUse - if the CA certificate is being
#       used by other modules

sub revokeCACertificate
  {

    my ($self, %args) = @_;

    # Check certificates is not in used
    if ($args{force}) {
      $self->_freeCert(undef, 1);
    }
    elsif( $self->_certsInUse(undef, 1) ){
      throw EBox::Exceptions::DataInUse();
    }

    # Revoked all issued and valid certificates
    # Revoked only valid ones
    # We ensure not to revoke the CA cert before the others
    my $listCerts = $self->listCertificates( state => 'V',
                                             excludeCA => 1);
    foreach my $element (@{$listCerts}) {
	$self->revokeCertificate(commonName    => $element->{dn}->attribute('commonName'),
				 reason        => "cessationOfOperation",
				 caKeyPassword => $args{caKeyPassword},
                                 force         => $args{force},
				);
    }

    my $retVal = $self->revokeCertificate(commonName    => "",
					  reason        => $args{reason},
					  caKeyPassword => $args{caKeyPassword},
					  certFile      => CACERT,
                                          force         => $args{force});

    $self->{caExpirationDate} = undef;

    # Logging the action
#    logAdminNow($self->name, "revokeCACertificate",
#		"reason=" . $args{reason} . ",force=$force"
#	       );


    return $retVal;

  }

# Method: issueCACertificate
#
#       Issue a self-signed CA certificate
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
#       caKeyPassword - key passpharse for CA (Optional)
#       genPair - if you want to generate a new key pair (Optional)
#
# Returns:
#
#      the new certificate file path
#
# Exceptions:
#
#      DataMissing - if any required parameter is missing
#      External    - if a CA certificate is already valid

sub issueCACertificate
  {

    my ($self, %args) = @_;

    throw EBox::Exceptions::DataMissing(data => __('Organization Name'))
      unless defined( $args{orgName} );

    # Define the distinguished name -> default values in configuration file
    $args{commonName} = CA_CN_DEF unless ( $args{commonName} );
    $self->{dn} = EBox::CA::DN->new ( countryName          => $args{countryName},
				      stateName            => $args{stateName},
				      localityName         => $args{localityName},
				      organizationName     => $args{orgName},
				      organizationNameUnit => $args{orgNameUnit},
				      commonName           => $args{commonName});

    if ( $self->currentCACertificateState() eq 'V') {
	throw EBox::Exceptions::External(
	 __('The CA certificates should be revoked  or has expired before issuing a new certificate'));
    }

    # Erase the previous cert request to generate a new key pair
    if ( $args{genPair} ) {
      unlink (CAREQ);
      unlink (CAPRIVKEY);
    }

    my $ret = $self->issueCertificate(commonName     => $self->{dn}->attribute('commonName'),
				      countryName    => $self->{dn}->attribute('countryName'),
				      localityName   => $self->{dn}->attribute('localityName'),
				      orgName        => $self->{dn}->attribute('orgName'),
				      orgNameUnit    => $self->{dn}->attribute('orgNameUnit'),
				      keyPassword    => $args{caKeyPassword},
				      days           => $args{days},
				      caKeyPassword  => $args{caKeyPassword},
				      privateKeyFile => CAPRIVKEY,
				      requestFile    => CAREQ,
				      certFile       => CACERT);

    # Expiration CA certificate
    $self->{caExpirationDate} = $self->_obtain(CACERT, 'endDate');

    # Logging the action
#    logAdminNow($self->name, "issueCACertificate",
#		"orgName=" . $self->{dn}->attribute("orgName") . ",days=" . $args{days}
#	       );

    $self->_setPasswordRequired( defined( $args{caKeyPassword} ));

    return $ret;

  }

# Method: renewCACertificate
#
#       Renew the self-signed CA certificate. Re-signs all the issued
#       certificates with the same expiration date or the CA
#       expiration date if the issued certificate is later.
#
#
# Parameters:
#
#       commonName - the CA common name *(Optional)*
#       countryName - country name {2 letter code} (eg, ES) *(Optional)*
#       stateName - state or province name (eg, Zaragoza) *(Optional)*
#       localityName - locality name (eg, Zaragoza) *(Optional)*
#
#       orgName - organization name (eg, company) *(Optional)*
#
#       orgNameUnit - organizational unit name (eg, section)
#                     *(Optional)*
#       days - days to hold the same certificate *(Optional)*
#       caKeyPassword - key passpharse for CA *(Optional)*
#       force - forcing the renewal of all the certificates *(Optional)*
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

    $self->{caKeyPassword} = $args{caKeyPassword};

    my $listCerts = $self->listCertificates();

    my $renewedCert = $self->renewCertificate( countryName   => $args{countryName},
					       stateName     => $args{stateName},
					       localityName  => $args{localityName},
					       orgName       => $args{orgName},
					       orgNameUnit   => $args{orgNameUnit},
					       days          => $args{days},
					       caKeyPassword => $args{caKeyPassword},
					       certFile      => CACERT,
					       reqFile       => CAREQ,
					       privateKeyFile => CAPRIVKEY,
					       keyPassword   => $args{caKeyPassword},
					       overwrite     => "1",
					       force         => $args{force},
					     );

    # Expiration CA certificate
    $self->{caExpirationDate} = $self->_obtain(CACERT, 'endDate');

    # Re-signs all the issued certificates with the same expiry date
    foreach my $element (@{$listCerts}) {
      # Renew the previous ones that remains valid
      if ($element->{state} eq 'V' and
	  -f ( KEYSDIR . $element->{dn}->attribute('commonName') . ".pem") ) {

	my $userExpiryDate = $element->{expiryDate};

	$userExpiryDate = $self->{caExpirationDate}
	  if ( $element->{expiryDate} gt $self->{caExpirationDate} );

	$self->renewCertificate( commonName    => $element->{dn}->attribute('commonName'),
				 endDate       => $userExpiryDate,
				 caKeyPassword => $args{caKeyPassword},
				 force         => $args{force},
			       );

      }

    }

    # Logging the action
#    logAdminNow($self->name, "reneweCACertificate",
#		"orgName=" . $self->{dn}->attribute("orgName") . ",days=" . $args{days}
#	       );

    return $renewedCert;

  }

# Method: CAPublicKey
#
#       Return the public key and certificate file from the
#       Certificate Authority
#
# Parameters:
#
#       caKeyPassword - the passphrase to access to private key
#       (Optional)
#
# Returns:
#
#       Path to the file which contains the CA Public Key in PEM
#       format or undef if it was not possible to retrieve
#

sub CAPublicKey {

  my ($self, $caKeyPassword) = @_;

  if (-f CAPUBKEY) {
    return CAPUBKEY;
  }

  # If does NOT exist, we have to generate it
  $caKeyPassword = $self->{caKeyPassword}
    unless ( defined ($caKeyPassword) );

  return $self->_getPubKey(CAPRIVKEY, CAPUBKEY, $caKeyPassword);

}

# Method: issueCertificate
#
#       Create a new certificate for an requester
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
#       keyPassword - passphrase for the private key (Optional)
#       days - expiration days of certificate (Optional)
#              Only valid if endDate is not present
#       endDate - explicity expiration date (Optional)
#                 A Date::Calc::Object
#       caKeyPassword - passphrase for CA to sign (Optional)
#       privateKeyFile - path to the private key file if there is already
#                        a private key file in the CA (Optional)
#
#       requestFile - path to save the new certificate request
#                    (Optional) 
#       certFile - path to store the new certificate file (Optional)
#
#
# Returns:
#
#      undef if no problem has happened
#
# Exceptions:
#
# External - if the CA passpharse CANNOT be located
#            if the expiration date from certificate to issue is later than CA
#            certificate expiration date
#            if any error happens in signing request process
#
# DataMissing - if any required parameter is missing
#

sub issueCertificate
  {

  my ($self, %args) = @_;

  # Treat arguments
  throw EBox::Exceptions::DataMissing(data => __('Common Name'))
    unless defined( $args{commonName} );

  EBox::warn("Two ways to declare expiration date through days and endDate. "
	     . "Using endDate...")
      if ( defined( $args{days} ) and defined( $args{endDate} ) );

  my $days = undef;
  if (not defined($args{endDate}) ) {
    $days = $args{days};
    $days = 365 unless $days;
    if ( $days > $self->{maxDays} ) {
      $days = $self->{maxDays};
      # It should be $self->{maxDays} but OpenSSL 0.9.7 lacks in other point
      # Another workaround should be, put the enddate explicity
      # Warning -> Year 2038 Bug
      # http://www.mail-archive.com/openssl-users@openssl.org/msg45886.html
      EBox::warn(__x("Days set to the maximum allowed {days}: Year 2038 Bug",
		     days => $self->{maxDays}));
    }
  }

  # Check the expiration date unless issuing the CA
  if (not defined($args{certFile}) or
      $args{certFile} ne CACERT) {
    my $userExpDay = undef;
    if ( defined($days) ) {
      $userExpDay = Date::Calc::Object->now();
      $userExpDay += [0, 0, $days, 0, 0, 0];
    } elsif (defined $args{endDate}) {
      $userExpDay = $args{endDate};
    }

    $self->{caExpirationDate} = $self->_obtain(CACERT, "endDate")
      unless defined($self->{caExpirationDate});

    if ( $userExpDay gt $self->{caExpirationDate} ) {
      throw EBox::Exceptions::External(__("Expiration date later than CA certificate expiration date"));
    }
  }


  if ( defined($args{caKeyPassword}) ) {
    $self->{caKeyPassword} = $args{caKeyPassword};
  }

  # Name the private key and the user requests by common name
  my $privKey = PRIVDIR . "$args{commonName}.pem";
  $privKey = $args{privateKeyFile} if ($args{privateKeyFile});
  my $pubKey = KEYSDIR . "$args{commonName}.pem";
  my $userReq = REQDIR . "$args{commonName}.pem";
  $userReq = $args{requestFile} if ($args{requestFile});
  my $certFile = $args{certFile};

  # Define the distinguished name
  # We take the default values from CA dn
  if ( not defined ( $self->{dn} ) ) {
    $self->{dn} = $self->_obtain(CACERT, 'DN');
  }
  my $dn = $self->{dn}->copy();
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

  # Create the certificate request
  my $genKey = 1;
  if ( defined($args{privateKeyFile} )) {
    if (-f $args{privateKeyFile} ) {
      $genKey = 0;
    }
  }

  my $output = $self->_createRequest(reqFile     => $userReq,
				     genKey      => $genKey,
				     privKey     => $privKey,
				     keyPassword => $args{keyPassword},
				     dn          => $dn,
				     needPass    => defined($args{keyPassword})
				    );

  if ( defined($output) ) {
    throw EBox::Exceptions::External($self->_filterErrorFromOpenSSL($output));
  }

  # Signs the request
  my $selfSigned = "0";
  if ( defined ($certFile) ) {
    $selfSigned = $certFile eq CACERT;
  }

  $output = $self->_signRequest( userReqFile  => $userReq,
				 days         => $days,
				 userCertFile => $certFile,
				 selfsigned   => $selfSigned,
				 endDate      => $args{endDate}
			       );

  # Check if something goes wrong
  if ( defined($output) ) {
    throw EBox::Exceptions::External($output);
  }

  # Generate the public key file (if it is a newly created private
  # key)
  if (not defined($args{privateKeyFile}) ) {
    my $result = $self->_getPubKey($privKey,
				   $pubKey,
				   $args{keyPassword});
  }

  # Logging the action
#  logAdminNow($self->name, "issueCertificate",
#		"cn=" . $args{commonName} . ",days=" . $args{days}
#	       );
#
  return $self->_findCertFile($args{"commonName"});

}

# Method: revokeCertificate
#
#       Revoke a certificate given the common name
#
# Parameters:
#
#       commonName - the common name with the certificate to revoke
#       reason - the reason to revoke the certificate. It can be:
#                unspecified, keyCompromise, CACompromise,
#                affiliationChanged, superseeded, cessationOfOperation
#                or certificationHold (Optional)
#       caKeyPassword - the CA passpharse (Optional)
#       certFile - the Certificate to revoke (Optional)
#       force    - Force the revokation (Optional)
#
# Returns:
#
#       undef if OK
#
# Exceptions:
#
#      <EBox::Exceptions::External> - if the certificate does NOT exist
#           if the reason is NOT a standard one
#           if any error occurred when revokation is done
#           if any error occurred when creating the CRL is done
#      <EBox::Exceptions::DataMissing> - if any required
#           parameter is missing
#      <EBox::Exceptions::DataInUse> - if the
#           certificate to revoke is being used by other modules
#
sub revokeCertificate {

  my ($self, %args) = @_;
  my $commonName = $args{commonName};
  my $reason = $args{reason};
  my $caKeyPassword = $args{caKeyPassword};
  my $certFile = $args{certFile};

  throw EBox::Exceptions::DataMissing(data => __('Common Name') )
    unless defined($commonName);

  if ( defined($caKeyPassword) ) {
    $self->{caKeyPassword} = $caKeyPassword;
  }

  # RFC 3280 suggests not to use an unspecified reason when the reason
  # is unknown.
  $reason = "unspecified" unless defined($reason);

  $certFile = $self->_findCertFile($commonName) unless defined ($certFile);

  throw EBox::Exceptions::External(__x('Certificate with common name {cn} does NOT exist',
				       cn => $commonName))
    unless (defined($certFile) and -f $certFile);

  throw EBox::Exceptions::External(__x("Reason {reason} is NOT an applicable reason.\n"
				       . "Options:" . $self->{reasons}, reason => $reason))
    unless $reason eq any(@{$self->{reasons}});

  # Tell observers the following certificate will be revoked
  if ( not defined ( $self->{dn} ) ) {
    $self->{dn} = $self->_obtain(CACERT, 'DN');
  }
  my $isCACert = $self->{dn}->attribute('commonName') eq $commonName;

  if ( $args{force} ) {
    $self->_freeCert($commonName, $isCACert);
  }
  elsif ( $self->_certsInUse($commonName, $isCACert) ) {
    throw EBox::Exceptions::DataInUse("Certificate $commonName in use");
  }

  # TODO: Different kinds of revokations (CACompromise,
  # keyCompromise...) 
  # We can set different arguments regard to revocation reason
  my $cmd = "ca";
  $self->_commonArgs("ca", \$cmd);
  $cmd .= "-revoke \'$certFile\' ";
  if ( defined($self->{caKeyPassword}) ) {
    $cmd .= "-passin env:PASS ";
  }
  $cmd .= "-crl_reason $reason " if (defined($reason));

  # Tell openssl to revoke
  $ENV{'PASS'} = $self->{caKeyPassword} 
    if (defined($self->{caKeyPassword}));
  my ($retValue, $output) = $self->_executeCommand(COMMAND => $cmd);
  delete ($ENV{'PASS'});

  # If any error is shown from revocation, the result is got back
  throw EBox::Exceptions::External($self->_filterErrorFromOpenSSL($output))
    if ($retValue eq "ERROR");

  # Generate a new Certification Revocation List (For now in the same
  # method...)

  # Localtime
  (my $day, my $month, my $year) = Date::Calc::Today();

  my $date = sprintf("%04d-%02d-%02d", $year+1900, $month+1, $day);

  $cmd= "ca";
  $self->_commonArgs("ca", \$cmd);
  $cmd .= "-gencrl ";
  if ( defined($self->{caKeyPassword}) ){
    $cmd .= "-passin env:PASS ";
  }
  $cmd .= "-out " . CRLDIR . $date . "-crl.pem";

  $ENV{'PASS'} = $self->{caKeyPassword}
    if (defined($self->{caKeyPassword}));
  ($retValue, $output) = $self->_executeCommand(COMMAND => $cmd);
  delete ($ENV{'PASS'});

  throw EBox::Exceptions::External($self->_filterErrorFromOpenSSL($output))
    if ($retValue eq "ERROR");

  # Set the link to the last
  unlink (LASTESTCRL) if ( -e LASTESTCRL );
  symlink ( CRLDIR . $date . "-crl.pem", LASTESTCRL );

  # Mark this module as changed
  $self->setAsChanged();

  # Logging the action
#  logAdminNow($self->name, "revokeCertificate",
#		"cn=" . $args{commonName} . ",reason=" . $args{reason} . ",force=$force"
#	       );

  return undef;

}

# Method: listCertificates
#
#       List the certificates that are ready on the system sorted
#       putting the CA certificate first and then valid certificates.
#       This list can be filtered according to an state, including or
#       not the CA certificate.
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
#       - Named parameters
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
#       - serialNumber - serial number within CA
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

    my @lines = read_file( INDEXFILE );
    my @out = ();

    foreach ( @lines ) {
      # Parse line with a tab
      my @line = split(/\t/);
      my %element;

      # Get current state
      $element{'state'} = $line[STATE_IDX];
      $element{'dn'} = EBox::CA::DN->parseDN($line[SUBJECT_IDX]);
      $element{'serialNumber'} = $line[SERIAL_IDX];

      # Set paramaters regarding to certificate validity
      if ($element{'state'} eq 'V') {
	$element{'expiryDate'} = $self->_parseDate($line[EXPIRE_DATE_IDX]);
	$element{'isCACert'} = $self->_isCACert($element{'dn'});
      } else {
	my $field = $line[REV_DATE_REASON_IDX];
	my ($revDate, $reason) = split(',', $field);
	$element{'revokeDate'} = $self->_parseDate($revDate);
	$element{'reason'} = $reason;
      }

      # Setting certificate path
      if ($element{'isCACert'}) {
	$element{'path'} = CACERT;
      } else {
	$element{'path'} = CERTSDIR . $line[SERIAL_IDX] . ".pem";
      }

      push (@out, \%element);

    }

    # Setting the filters
    if ( defined($state) ) {
      # Filter according to state
      @out = grep { $_->{state} eq $state } @out;
    }
    if ( $excludeCA ) {
      # Filter the valid CA certificate
      @out = grep { not $_->{isCACert} } @out;
    }

    # Sort the array to have CA certs first (put latest first)
    my @sortedOut = sort { $b->{state} cmp $a->{state} } @out;

    return \@sortedOut;

  }

# Method: getCertificateMetadata
#
#       Given an attribute to filter, returns an unique certificate metadata.
#       JUST ONE parameter can be passed.  To return the CA
#       certificate, it is recommended to use <getCACertificateMetadata>.
#
# Parameters:
#
#       cn - Common Name (Optional)
#       dn - EBox::CA::DN Distinguished Name (Optional)
#       serialNumber - A serial number within CA (Optional)
#
# Returns:
#
#       A reference to a hash with the following elements
#
#       - dn         - an <EBox::CA::DN> object
#       - state      - 'V' from Valid, 'R' from Revoked or 'E' from Expired
#       - expiryDate - the expiry date in a <Calc::Date::Object> if state valid
#
#       - revokeDate - the revocation date in a Date hash if state is
#                    revoked
#       - reason     - reason to revoke if state is revoked
#       - path       - certificate path
#       - serialNumber - serial number within CA
#
# Exceptions:
#
#      <EBox::Exceptions::DataMissing> - if any required parameter is missing

sub getCertificateMetadata
  {
    my ($self, %args) = @_;

    if (scalar(keys %args) == 0) {
      throw EBox::Exceptions::DataMissing(data =>
        __("Either common name, distinguished name or serial number has been passed")
					 );
    } elsif ( scalar(keys %args) > 1 ) {
      throw EBox::Exceptions::Internal("Only one parameter is necessary");
    } elsif ( defined($args{'dn'}) 
	      and not $args{'dn'}->isa('EBox::CA::DN') ) {
      throw EBox::Exceptions::Internal("dn parameter should be an instance of EBox::CA::DN");
    }

    my $cn = $args{'cn'};
    my $dn = $args{'dn'};
    my $serialNumber = $args{'serialNumber'};

    my $listCertsRef = $self->listCertificates();

    my $retCert = undef;
    if (defined($cn)) {
      # Looking for a particular cn
      ($retCert) = grep { $_->{'dn'}->attribute('commonName') eq $cn } @{$listCertsRef};
    } elsif(defined($dn)) {
      # Looking for a particular dn
      ($retCert) = grep { $_->{'dn'}->equals($dn) } @{$listCertsRef};
    } elsif( defined($serialNumber) ) {
      ($retCert) = grep { $_->{'serialNumber'} eq $serialNumber } @{$listCertsRef};
    }

    return $retCert;

  }

# Method: getCACertificateMetadata
#
#       Return the current metadata related to the valid Certification
#       Authority.
#
#
# Returns:
#
#    - A reference to a hash which the following elements
#
#       - dn         - an <EBox::CA::DN> object
#       - expiryDate - the expiry date in a <Calc::Date::Object> if state valid
#       - path       - certificate path
#
#    - Undef if the CA is expired or inexistent -> Check state
#      calling to <EBox::CA::currentCACertificateState>
#
sub getCACertificateMetadata
  {

    my ($self) = @_;

    my $certsRef = $self->listCertificates();

    # Find the CA certificate in the list
    my ($CACert) = grep { $_->{'isCACert'} } @{$certsRef} ;

    return $CACert;

  }


# Method: getKeys
#
#       Get the keys (public and private) from CA given an specific common name.
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

sub getKeys {

  my ($self, $commonName) = @_;

  throw EBox::Exceptions::DataMissing(data => __("Common Name"))
    unless defined ($commonName);

  my %keys;

  if (-f PRIVDIR . "$commonName.pem" ) {
    $keys{privateKey} = PRIVDIR . "$commonName.pem";
  }

  $keys{publicKey} = KEYSDIR . "$commonName.pem";

  throw EBox::Exceptions::External(__x('Certificate with common name {cn} does NOT exist',
				       cn => $commonName))
    unless (-f $keys{publicKey});

  # Remove private key when the CGI has sent the private key
  # DONE in removePrivateKey method
  return \%keys;

}

# Method: removePrivateKey
#
#       Remove the private key from an user
#
# Parameters:
#
#       commonName - the common name to identify the private key
#
# Returns:
#
#       1 - If everything OK
#
# Exceptions:
#
#      Internal -  if the private key does NOT exist
#      DataMissing - if common name is not provided
#
sub removePrivateKey
  {
    my ($self, $commonName) = @_;

    throw EBox::Exceptions::DataMissing(data => __('Common Name'))
	unless defined ($commonName);

    if (-f PRIVDIR . "$commonName.pem" ) {
      unlink (PRIVDIR . "$commonName.pem");
      return 1;
    } else {
      throw EBox::Exceptions::Internal("Private key does NOT exist");
    }

  }

# Method: renewCertificate
#
#       Renew a certificate from a user.
#       If any Distinguished Name is needed to change, it is done.
#
# Parameters:
#
#       commonName - the common name from the user. Not needed
#                    if a certificate file is given *(Optional)*
#
#       countryName - country name {2 letter code} (eg, ES) *(Optional)*
#       stateName - state or province name (eg, Zaragoza) *(Optional)*
#       localityName - locality name (eg, Zaragoza) *(Optional)*
#
#       orgName - organization name (eg, company) *(Optional)*
#
#       orgNameUnit - organizational unit name (eg, section)
#                     *(Optional)*
#       days - days to hold the same certificate *(Optional)*
#              Only if enddate not appeared
#       endDate - the exact date when the cert expired *(Optional)*
#                 Only if days not appeared
#                 It is a Date::Calc::Object
#       caKeyPassword - key passpharse for CA *(Optional)*
#       certFile - the certificate file to renew *(Optional)*
#       reqFile  - the request certificate file which to renew *(Optional)*
#
#       privateKeyFile - the private key file *(Optional)*
#       keyPassword - the private key passpharse. It is used when
#       a new request is issued, not compulsory anyway. *(Optional)*
#
#       overwrite - overwrite the current certificate file. Only if
#       the certFile is passed *(Optional)*
#
#       force - this forces the revokation pass to do the renewal *(Optional)*
#
# Returns:
#
#       the new certificate file path
#
# Exceptions:
#
# <EBox::Exceptions::External> - if the user does NOT exist,
#                                if the expiration date for the certificate to renew is later than CA certificate expiration date
#                                if the certificate to renew does NOT exist
#                                if any error occurred when certificate renewal is done
# <EBox::Exceptions::Internal> - if any parameter is an unexcepted type
# <EBox::Exceptions::DataMissing> - if no CA passphrase is given to renew the certificate
# <EBox::Exceptions::DataInUse> - if the certificate to renew is in use and no forcing is done
#

sub renewCertificate
  {

    my ($self, %args) = @_;

    if (not defined($args{endDate}) ) {
      $args{days} = 365 unless defined ($args{days});
      if ( $args{days} > $self->{maxDays} ) {
	$args{days} = $self->{maxDays};
	# Warning -> Year 2038 Bug
	# http://www.mail-archive.com/openssl-users@openssl.org/msg45886.html
	EBox::warn(__x("Days set to the maximum allowed {days}: Year 2038 Bug",
		       days => $self->{maxDays}));
      }
    }

    throw EBox::Exceptions::Internal("End date parameter (" . ref($args{endDate}) . " is not a Date::Calc object")
      if (defined($args{endDate}) and not UNIVERSAL::isa($args{endDate}, "Date::Calc"));

    # Check the expiration date unless issuing the CA cert
    unless (defined($args{certFile}) or $args{certFile} eq CACERT) {
      my $userExpDay = undef;
      if ( defined($args{days}) ) {
	$userExpDay = Date::Calc::Object->now() + [0, 0, +$args{days}, 0, 0, 0];
      } elsif ( defined($args{endDate}) ) {
	$userExpDay = $args{endDate};
      }

      $self->{caExpirationDate} = $self->_obtain(CACERT, "endDate")
	unless defined($self->{caExpirationDate});

      if ( $userExpDay gt $self->{caExpirationDate} ) {
	throw EBox::Exceptions::External(__("Expiration date later than CA certificate expiration date"));
      }
    }

    throw EBox::Exceptions::DataMissing(data => __('Common Name')
					. " " . __("or") . " " .
					__('Certificate file'))
      unless defined ($args{commonName}) or defined ($args{certFile});

    if ( defined($args{caKeyPassword}) ) {
      $self->{caKeyPassword} = $args{caKeyPassword};
    }

    my $overwrite = $args{overwrite} if ($args{certFile});

    my $userCertFile;
    if ( defined($args{certFile})) {
      $userCertFile = $args{certFile};
    } else {
      $userCertFile = $self->_findCertFile($args{commonName});
    }

    my $selfsigned = "0";
    $selfsigned = "1" if ($userCertFile eq CACERT);

    my $userDN = $self->_obtain($userCertFile, 'DN');

    if ( not defined($userDN) ) {
      throw EBox::Exceptions::External(__("The certificate to renew does NOT exist"));
    }

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

    # Revoke old certificate
    my $retVal = $self->revokeCertificate(commonName    => $userDN->attribute('commonName'),
					  reason        => "superseded",
					  certFile      => $userCertFile,
					  caKeyPassword => $args{caKeyPassword},
					  force         => $args{force},
					 );

    if (defined($retVal) ) {
      throw EBox::Exceptions::External(__x("Certificate with this common name {cn} does NOT exist in this CA"
					   , cn => $userDN->attribute('commonName')));
    }
    # Sign a new one
    my $userReq;
    if ( defined($args{reqFile}) ) {
      $userReq = $args{reqFile};
    } else {
      $userReq = REQDIR . $userDN->attribute('commonName') . ".pem";
    }

    # Overwrite the current certificate? Useful?
    my $newCertFile = undef;
    if ($overwrite) {
      $newCertFile = $userCertFile;
    }

    if (-f $userReq) {
      # If the request exists, we can renew the certificate without
      # having the private key

      # New subject
      my $newSubject = undef;
      if ( $dnFieldHasChanged ) {
	$newSubject = $userDN;
	# For OpenSSL 0.9.7, we need to create the request
	my $privKeyFile = PRIVDIR . $userDN->attribute('commonName') . ".pem";
	$privKeyFile = $args{privateKeyFile} if ($args{privateKeyFile});
	throw EBox::Exceptions::External(__("The private key passpharse needed to create a new request. No renewal was made. Issue a new certificate with new keys"))
	  if ( not defined($args{keyPassword}) );

	my $output = $self->_createRequest(reqFile     => $userReq,
					   genKey      => 0,
					   privKey     => $privKeyFile,
					   keyPassword => $args{keyPassword},
					   dn          => $newSubject,
					   needPass    => defined($args{keyPassword})
					  );

	if ($output) {
	  throw EBox::Exceptions::External($self->_filterErrorFromOpenSSL($output));
	}

	$self->{dn} = $newSubject if (defined($newCertFile)
				      and $newCertFile eq CACERT);
      }

      my $output = $self->_signRequest( userReqFile  => $userReq,
					days         => $args{days},
					userCertFile => $newCertFile,
					selfsigned   => $selfsigned,
					createSerial => 0,
# Not in OpenSSL 0.9.7			newSubject   => $newSubject,
					endDate      => $args{endDate}
				      );

      if (defined($output) ) {
	throw EBox::Exceptions::External($output);
      }

    } else {
      # If we don't keep the request, we should create a new one with
      # the private key if exists. If not, we need to recreate all...
      # by using issuing a new certificate with a new request
      my $privKeyFile = PRIVDIR . $userDN->attribute('commonName') . ".pem";
      $privKeyFile = $args{privateKeyFile} if ($args{privateKeyFile});

      $self->issueCertificate( countryName  => $userDN->attribute('countryName'),
			       stateName    => $userDN->attribute('stateName'),
			       localityName => $userDN->attribute('localityName'),
			       orgName      => $userDN->attribute('orgName'),
			       orgNameUnit  => $userDN->attribute('orgNameUnit'),
			       commonName   => $userDN->attribute('commonName'),
			       keyPassword  => $args{keyPassword},
			       days         => $args{days},
			       privateKeyFile => $privKeyFile,
			       requestFile    => $userReq,
			       certFile       => $newCertFile,
			       endDate        => $args{endDate});
    }

    if (not defined($newCertFile) ) {
      $newCertFile = $self->_findCertFile($userDN->attribute('commonName'));
    }

    # Logging the action
#    logAdminNow($self->name, "renewCertificate",
#		"cn=" . $args{commonName} . ",days=" . $args{days}
#	       );

    return $newCertFile;

  }

# Method: updateDB
#
#       Update the index.txt file to mark the expired certificates
#       Called by the controller.
#
# Parameters:
#
#       caKeyPassword - key passpharse for CA (Optional)
#
# Returns:
#
#       undef if everything OK
#
# Exceptions:
#
#      EBox::Exceptions::External - if the CA passpharse is incorrect

sub updateDB
  {

    my ($self, %args) = @_;

    # Manage the parameters
    my $caKeyPassword = $args{caKeyPassword};

    if ( defined($caKeyPassword) ) {
      $self->{caKeyPassword} = $caKeyPassword;
    }

    my @expiredCertsBefore = $self->listCertificates(state => 'E');

    my $cmd = "ca";
    $self->_commonArgs("ca", \$cmd);
    $cmd .= "-updatedb ";
    if ( defined($self->{caKeyPassword}) ){
      $cmd .= "-passin env:PASS ";
    }

    $ENV{'PASS'} = $self->{caKeyPassword};
    my ($retVal, $output) = $self->_executeCommand( COMMAND => $cmd );
    delete( $ENV{'PASS'} );

    my @expiredCertsAfter = $self->listCertificates(state => 'E');
    # Finding elements in one array but not another
    # T. Christiansen & N. Torkington, Perl Cookbook 2nd edition, pg. 126
    my %seen;
    @seen {@expiredCertsAfter} = ();
    delete @seen {@expiredCertsBefore};

    my @diff = keys %seen;
    # Tells other modules the following certs have expired
    my $global = EBox::Global->getInstance();
    my @mods = @{$global->modInstancesOfType('EBox::CA::Observer')};
    foreach my $cert (@diff) {
      foreach my $mod (@mods) {
	$mod->certificateExpired($cert->{dn}->attribute('commonName'),
				 $cert->{isCACert});
      }
    }

    if ($retVal eq "ERROR") {
      throw EBox::Exceptions::External($self->_filterErrorFromOpenSSL($output));
    }

    # Logging the action
#    logAdminNow($self->name, "updateDB",
#		"number=" . scalar(@diff)
#	       );

    return undef;

  }

# Method: currentCACertificateState
#
#       Return the current state for the CA Certificate
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

    my $serialCert = $self->_obtain(CACERT, 'serial');

    return '!' unless (defined($serialCert));

    my $certRef = $self->getCertificateMetadata(serialNumber => $serialCert);

    if ( not defined($certRef) ) {
      return "!";
    } else {
      return $certRef->{'state'};
    }

}

# Method: revokeReasons
#
#       Return the current list of possible revoke reasons
#
# Returns:
#
#       A reference to the array containing the current list of possible revoke reasons
#
sub revokeReasons
  {

    my ($self) = @_;

    return $self->{reasons};

  }

# Method: getCurrentCRL
#
#       Return the current Certification Revokation List (CRL)
#
# Returns:
#
#       Path to the current CRL or undef if there is no CRL
#
sub getCurrentCRL
  {

    my ($self) = @_;

    if ( -e LASTESTCRL ) {
      return LASTESTCRL;
    }
    else {
      return undef;
    }

  }


# _regenConfig is not longer needed 'cause this module doesn't manage a daemon

# The method summary is not neccessary since it is not a network service

# Method: menu
#
#       Add CA module to eBox menu
#
# Parameters:
#
#       root - the <EBox::Menu::Root> where to leave our items
#

sub menu
  {

  my ($self, $root) = @_;

  $root->add(new EBox::Menu::Item('url'  => 'CA/Index',
				  'text' => __('Certificate Manager')));

  }

# Method: dumpConfig
#
#       Dump CA configuration and certificates
#
# Parameters:
#
#       dir - Directory where the modules backup files are dumped
#
sub dumpConfig
  {

    my ($self, $dir) = @_;

    # Call super
    $self->SUPER::dumpConfig($dir);

    if ( -d CATOPDIR ) {
      # Storing all OpenSSL directory tree where Certs/keys and DB are stored
      dircopy(CATOPDIR, $dir . "/CA");
    }

    if ( -f SSLCONFFILE ) {
      # Storing OpenSSL config file
      fcopy(SSLCONFFILE, $dir . "/openssl.cnf");
    }

  }

# Method:  restoreConfig
#
#   Restore its configuration from the backup file. Those files are
#   the same were created with dumpConfig
#
# Parameters:
#  dir - Directory where are located the backup files
#
sub restoreConfig
  {

    my ($self, $dir) = @_;

    # Call super
    $self->SUPER::restoreConfig($dir);
    # Destroy previous CA
    $self->destroyCA();
    # Restoring all OpenSSL directory tree where Certs/keys and DB are stored
    my $dataDir = $dir . '/CA';
    if (-d $dataDir) {
      dircopy($dataDir, CATOPDIR);
    }

    # Restoring OpenSSL config file
    fcopy($dir . "/openssl.cnf", SSLCONFFILE);

  }

# Group: Private methods

# Obtain the public key given the private key 
#
# Return public key path if it is correct or undef if password is
# incorrect

sub _getPubKey # (privKeyFile, pubKeyFile, password?)
  {

    my ($self, $privKeyFile, $pubKeyFile, $password)  = @_;

    $pubKeyFile = TEMPDIR . "pubKey.pem" unless (defined ($pubKeyFile));

    my $cmd = "rsa ";
    $cmd .= "-in \'$privKeyFile\' ";
    $cmd .= "-out \'$pubKeyFile\' ";
    $cmd .= "-outform PEM ";
    $cmd .= "-pubout ";
    if ( defined($password) ) {
      $cmd .= "-passin env:PASS ";
    }

    $ENV{'PASS'} = $password 
      if (defined($password));
    my ($retVal) = $self->_executeCommand(COMMAND => $cmd);
    delete( $ENV{'PASS'} );

    return undef if ($retVal eq "ERROR");

    return $pubKeyFile;

  }

# Given a serial number, it returns the file path
sub _certFile {

  my $self = shift;
  my $serial = shift;

  my $file = CATOPDIR . "newcerts/${serial}.pem";
  
  return $file

}

# Given a common name, it returns the file path to the valid certificate
# file which has as a subject a dn with this common name
# Undef if the certificate does NOT exist
# Path to the certificate if the certificate exists
sub _findCertFile # (commonName)
  {

    my ($self, $commonName) = @_;

    open (my $fh, '<', INDEXFILE);

    my $found = '0';
    my $certFile = undef;
    while(defined(my $line = <$fh>) and not $found) {

      my @fields = split ('\t', $line);

      if ( $fields[STATE_IDX] eq 'V') {
	# Extract cn from subject
	my $subject = EBox::CA::DN->parseDN($fields[SUBJECT_IDX]);
	$found = $subject->attribute("commonName") eq $commonName;
	if ($found) {
	  $certFile = CERTSDIR . $fields[SERIAL_IDX] . ".pem";
	  return $certFile;
	}
      }

    }
    return $certFile;

  }

# Create a request certificate
# return undef if any error occurs
sub _createRequest # (reqFile, genKey, privKey, keyPassword, dn, needPass?)
  {

    my ($self, %args) = @_;

    # To create the request the distinguished name is needed
    my $cmd = 'req';
    $self->_commonArgs('req', \$cmd);

    $cmd .= '-new ';
    $self->_commonArgs('req', \$cmd);
    if ($args{genKey}) {
      $cmd .= qq{-keyout '$args{privKey}' };
      if (defined($args{keyPassword})) {
	$cmd .= '-passout env:PASS ';
      } else {
	# If the password is undefined, the keys are created and left
	# unencrypted
	$cmd .= '-nodes ';
      }
    } else {
      $cmd .= qq{-key '$args{privKey}' };
      if ($args{needPass}) {
	$cmd .= '-passin env:PASS ';
      }
    }

    $cmd .= qq{-out '$args{reqFile}' };
    $cmd .= "-subj '" . $args{dn}->stringOpenSSLStyle() . "' ";
    # Not implemented till 0.9.8
    # $cmd .= '-multivalue-rdn ' if ( $args{dn}->stringOpenSSLStyle()
    # =~ /[^\\](\\\\)*\+/);

    # We have to define the environment variable PASS to pass the
    # password
    $ENV{'PASS'} = $args{keyPassword} if ( defined($args{keyPassword}));
    # Execute the command
    my ($retVal, $output) = $self->_executeCommand(COMMAND => $cmd);
    delete( $ENV{'PASS'} );

    return $output if ($retVal eq 'ERROR');
    return;

  }

# Sign a request
# return the output error if any error occurr, nothing otherwise
# ? Optional Parameter
sub _signRequest # (userReqFile, days, userCertFile?, policy?, selfsigned?,
                 # newSubject?, endDate?)
  {

    my ($self, %args) = @_;

    # For OpenSSL 0.9.7
    if ($args{selfsigned}) {
      my $output = $self->_signSelfSignRequest( userReqFile  => $args{userReqFile},
						days         => $args{days},
						userCertFile => $args{userCertFile},
						policy       => $args{policy},
						newSubject   => $args{newSubject},
						endDate      => $args{endDate},
						keyFile      => CAPRIVKEY);

      $self->{dn} = $args{newSubject} if (defined($args{newSubject}));

      # If any error has occurred return inmediately
      if ( $output) {
	return $output;
      }

      # Put in the index.txt file (update database...)
      $self->_putInIndex(dn           => $self->{dn},
			 certFile     => CACERT,
			 serialNumber => $self->_obtain(CACERT,'serial'));
      return $output;

    }

    my $policy = "policy_anything" unless (defined($args{policy}));

    my $endDate = $self->_flatDate($args{endDate}) if defined($args{endDate});

    # Sign the request
    my $cmd = "ca";
    $self->_commonArgs("ca", \$cmd);
    # Only available since OpenSSL 0.9.8
    # $cmd .= "-create_serial "if ($args{createSerial});
    if (defined($self->{caKeyPassword})) {
      # it can be no pass for CA key
      $cmd .= "-passin env:PASS ";
    }
    $cmd .= "-outdir " . CERTSDIR . " ";
    $cmd .= "-out \'$args{userCertFile}\' " if defined($args{userCertFile});
    $cmd .= "-extensions v3_ca " if ( EXTENSIONS_V3);
    # Only available in OpenSSL 0.9.8
    $cmd .= "-selfsign " if ($args{selfsigned});
    $cmd .= "-policy $policy ";
    $cmd .= "-keyfile " . CAPRIVKEY . " ";
    $cmd .= "-days $args{days} " if defined($args{days});
    $cmd .= "-enddate " . $self->_flatDate($args{endDate}) . " " if defined($args{endDate});
    if ( defined($args{newSubject}) ) {
      $cmd .= "-subj \"". $args{newSubject}->stringOpenSSLStyle() . "\" ";
      $cmd .= "-multivalue-rdn " if ( $args{newSubject}->stringOpenSSLStyle() =~ /[^\\](\\\\)*\+/);
    }
    $cmd .= "-in \'$args{userReqFile}\'";

    $ENV{'PASS'} = $self->{caKeyPassword}
      if(defined($self->{caKeyPassword}));
    my ($retVal, $output) = $self->_executeCommand(COMMAND => $cmd);
    delete ( $ENV{'PASS'} );

    return $self->_filterErrorFromOpenSSL($output) if ($retVal eq "ERROR");
    return undef;

  }

# Sign a self-signed request (compatible with OpenSSL 0.9.7 series)
sub _signSelfSignRequest # (userReqFile, days?, userCertFile,
                         # serialNumber?, newSubject?, endDate?,
                         # keyFile)
  {

    my ($self, %args) = @_;

    my $endDate = $self->_flatDate($args{endDate}) if defined($args{endDate});

    # Sign the request
    my $cmd = "req";
    $self->_commonArgs("req", \$cmd);
    # Only available since OpenSSL 0.9.8
    # Maybe the password is not necessary
    if ( defined($self->{caKeyPassword}) ){
      $cmd .= "-passin env:PASS ";
    }
    $cmd .= "-out \'$args{userCertFile}\' " if defined($args{userCertFile});
    $cmd .= "-extensions v3_ca " if ( EXTENSIONS_V3);
    $cmd .= "-x509 ";
    $cmd .= "-set_serial \"0x$args{serialNumber}\" " if defined($args{serialNumber});
    $cmd .= "-days $args{days} " if defined($args{days});
    $cmd .= "-enddate " . $self->_flatDate($args{endDate}) . " " if defined($args{endDate});
    if ( defined($args{newSubject}) ) {
      $cmd .= "-subj \"". $args{newSubject}->stringOpenSSLStyle() . "\" ";
      $cmd .= "-multivalue-rdn " if ( $args{newSubject}->stringOpenSSLStyle() =~ /[^\\](\\\\)*\+/);
    }
    $cmd .= "-key $args{keyFile} ";
    $cmd .= "-in \'$args{userReqFile}\' ";
    
    $ENV{'PASS'} = $self->{caKeyPassword} 
      if (defined($self->{caKeyPassword}));
    my ($retVal, $output) = $self->_executeCommand(COMMAND => $cmd);
    delete ( $ENV{'PASS'} );

    return $output if ($retVal eq "ERROR");
    return undef;

  }



# Taken the OpenSSL command (req, x509, rsa...)
# and add to the args the common arguments to all openssl commands
# For now, to req and ca commands, it adds config file and batch mode
# 
sub _commonArgs # (cmd, args)
  {

    my $self = shift;
    my ($cmd, $args ) = @_;

    if ( $cmd eq "ca" or $cmd eq "req" ) {
      ${$args} .= " -config " . SSLCONFFILE . " -batch ";
    }

  }

# Given a certification file Obtain an attribute from the file
# attribute => 'DN' return => EBox::CA::DN object
# attribute => 'serial' return => String containing the serial number
# attribute =>'endDate' return => Date::Calc::Object with the date
# attribute => 'days' return => number of days from today to expire
# undef => if certification file does NOT exist

sub _obtain # (certFile, attribute)
  {

    my ($self, $certFile ,$attribute) = @_;

    if (not -f $certFile) {
      return undef;
    }

    my $arg = "";
    if ($attribute eq 'DN') {
      $arg = "-subject";
    } elsif ($attribute eq 'serial') {
      $arg = "-serial";
    } elsif ($attribute eq 'endDate'
	    or $attribute eq 'days') {
      $arg = "-enddate";
    }
    my $cmd = "x509 " . $arg . " -in \'$certFile\' -noout";

    my ($retVal, $output) = $self->_executeCommand(COMMAND => $cmd);

    return undef if ($retVal ne "OK");

    # Remove the attribute name part
    $arg =~ s/-//g;
    if ($arg eq "enddate") {
      $arg = "notAfter";
    }

    $output =~ s/^$arg=( )*//g;

    chomp($output);

    if ($attribute eq 'DN') {
      return EBox::CA::DN->parseDN($output);
    } elsif ($attribute eq 'serial' ) {
      return $output;
    } elsif ($attribute eq 'endDate' ) {
      my ($monthStr, $day, $hour, $min, $sec, $yyyy) = 
	($output =~ /(.+) (\d+) (\d+):(\d+):(\d+) (\d+) (.+)/);

      $monthStr =~ s/ +//g;
      my $dateObj = Date::Calc->new($yyyy, 
				    Decode_Month($monthStr),
				    $day, $hour, $min, $sec);
      return $dateObj;
    } elsif ($attribute eq 'days') {
      my $certDate = $self->_parseDate($output);
      my $diffDate = $certDate - Date::Calc->Today();
      return $diffDate->day();
    }

  }

# Given the string date from index.txt file
# obtain the date as a Date::Calc::Object

sub _parseDate
  {
    my ($self, $str) = @_;

    my ($y,$mon,$mday,$h,$m,$s) = $str =~ /([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})Z$/;

    $y += 2000;
	# my $wday = Day_of_Week($y+1999,$mon,$mday);
    my $date = Date::Calc->new($y, $mon, $mday, $h, $m, $s);

    return $date;
  }

# A private method to flat a Date::Calc::Object to a OpenSSL form like
# YYMMDDHHMMSSZ 
sub _flatDate # (date)
  {
    my ($self, $date) = @_;

    return "" unless ( UNIVERSAL::isa($date, "Date::Calc"));

    my $dateStr =sprintf("%02d%02d%02d%02d%02d%02dZ",
			 $date->year() - 2000,
			 $date->month(),
			 $date->day(),
			 $date->hours(),
			 $date->minutes(),
			 $date->seconds());

    return $dateStr;

  }

# Create a serial number with 16 digits (a hex number)
# Return the 16-digit string
sub _createSerial
  {
    my $self = shift;

    srand();

    my $serial = sprintf("%08X", int(rand(hex('0xFFFFFFFF'))));

    $serial .= sprintf("%08X", int(rand(hex('0xFFFFFFFF'))));

    return $serial;

  }

# Get the maximum number of days to apply to a certificate expiration.
# This is the Year 2038 Bug, explained here -> 
# http://www.mail-archive.com/openssl-users@openssl.org/msg45886.html
sub _maxDays
  {

    my ($self) = @_;

    my $now = Date::Calc::Object->now();
    # The final day is 2038 19th 04:14:07 :-O
    my $year2038 = Date::Calc::Object->new(2038, 1, 19, 4, 14, 7);
    my $diff = $year2038 - $now;

    return $diff->day();

  }

# Print the row for CA cert in index.txt file (to fuck them up)
sub _putInIndex # (EBox::CA::DN dn, String certFile, String
                  # serialNumber) 
  {

    my ($self, %args) = @_;

    my $date = $self->_obtain($args{certFile}, 'endDate');

    my $row = "V\t";
    $row .= $self->_flatDate($date) . "\t\t";
    $row .= $args{serialNumber} . "\t";
    $row .= "unknown\t";
    # I found that every subject has no final slash
    my $subject = $args{dn}->stringOpenSSLStyle();
    $subject =~ s/\/$//g;
    $row .= $subject . "\n";

    open (my $index, ">>" . INDEXFILE);
    print $index $row;
    close($index);

  }

# Return if the given DN is the CA certificate file
sub _isCACert # (EBox::CA::DN dn)
  {

    my ($self, $dn) = @_;

    my $caDN = $self->_obtain(CACERT, 'DN');

    return $caDN->equals($dn);

  }

# Write down the next serial to serial file, given a certificate file
# Only useful under OpenSSL 0.9.7, later on fixed
sub _writeDownNextSerial # (certFile) 
  {

    my ($self, $certFile) = @_;

    my $cmd = "x509 ";
    $self->_commonArgs("x509", \$cmd);
    $cmd .= "-in \'$certFile\' ";
    $cmd .= "-noout ";
    $cmd .= "-next_serial ";
    $cmd .= "-out " . SERIALNOFILE;

    $self->_executeCommand(COMMAND => $cmd);

  }

# Write down the serial attribute file
# Only useful under OpenSSL 0.9.7, later on fixed
sub _writeDownIndexAttr # (attrFile)
  {
    my ($self, $attrFile) = @_;

    open(my $fh, ">" . $attrFile);
    print $fh "unique_subject = yes" . $/;
    close($fh);

  }

# Filter the given OpenSSL output from error to show normal messages
# Return a normal error message
# Welcome to the hell
sub _filterErrorFromOpenSSL # (input)
  {

    my ($self, $input) = @_;

    if( $input eq "1") {
      $input = "1";
    } elsif ( $input =~ m/unable to load CA private key/i ) {
      $input = __("Unable to sign. Wrong CA passphrase or has CA private key dissappeared?");
    } elsif ( $input =~ m/invalid expiry date/i ) {
      $input = __("Database corruption");
    } elsif ( $input =~ m/TXT_DB error number 2/i ) {
      $input = __("Identifier duplicated in Database");
    } elsif ( $input =~ m/Already revoked/i ) {
      $input = __("Certificate already revoked");
    } elsif ( $input =~ m/string too long/i ) {
      my ($maxSize) = ($input =~ /maxsize=(\d+)/ );
      $input = __("ASN1 field length too long. Maximum Size:") . $maxSize;
    } else {
      $input = __("Unknown error. Given the OpenSSL output:") . $/ . $input;
    }

    return $input;

  }

# Check none of other eBox modules uses the certificate
# Return true if there's any module using it
sub _certsInUse # (cn?, isCACert?)
  {
    my ($self, $cn, $isCACert) = @_;

    if ( not (defined($cn) and defined($isCACert)) ) {
      return undef;
    }

    if ( not defined ( $self->{dn} ) ) {
      $self->{dn} = $self->_obtain(CACERT, 'DN');
    }
    $cn = $self->{dn}->attribute('commonName')
      if ($isCACert);

    my $global = EBox::Global->getInstance();
    my @observers = @{$global->modInstancesOfType('EBox::CA::Observer')};
    foreach my $obs (@observers) {
      if( $obs->certificateRevoked($cn, $isCACert) ){
	return 1;
    }
    }

    return undef;

  }

# Force observers to free this certificate
sub _freeCert # (cn?, isCACert?)
  {

    my ($self, $cn, $isCACert) = @_;

    if ( not defined ( $self->{dn} ) ) {
      $self->{dn} = $self->_obtain(CACERT, 'DN');
    }

    $cn = $self->{dn}->attribute('commonName') if ($isCACert);

    my $global = EBox::Global->getInstance();
    my @observers = @{$global->modInstancesOfType('EBox::CA::Observer')};
    foreach my $obs (@observers) {
        $obs->freeCertificate($cn);
    }

  }

# Set the CA as passwordful or passwordless
sub _setPasswordRequired # (required)
  {

    my ($self, $required) = @_;

    $self->set_bool('pass_required', $required);

  }

# Setting logAdmin actions
sub _setLogAdminActions
  {

    my ($self) = @_;

    $self->{actions} = {};
    $self->{actions}->{createCA} =
      __n("Created Certification Authority with organization name {orgName} and validity for {days} days");
    $self->{actions}->{destroyCA} =
      __n("Destroyed Certification Authority with organization name {orgName}");
    $self->{actions}->{revokeCACertificate} =
      __n("Revoked CA certificate because of {reason} forced: {force}");
    $self->{actions}->{issueCACertificate} =
      __n("Issued CA certificate with organization name {orgName} and validity for {days} days");
    $self->{actions}->{renewCACertificate} =
      __n("Renewed CA certificate with organization name {orgName} and validity for {days} days");
    $self->{actions}->{issueCertificate} =
      __n("Issued certificate with common name {cn} and validity for {days} days");
    $self->{actions}->{revokeCertificate} =
      __n("Revoked certificate with common name {cn} because of {reason} forced: {force}");
    $self->{actions}->{renewCertificate} =
      __n("Renewed certificate with common name {cn} and validity for {days} days");
    $self->{actions}->{updateDB} =
      __n("Updated certificate database. {number} certificates have expired");

    return;

}


## OpenSSL execution environment provided by OpenCA::OpenSSL
## through OpenCA application
## Modificated to adapt to OpenSSL environment

## Copyright (C) 1998-2001 Massimiliano Pala (madwolf@openca.org)
## All rights reserved.
##
## This library is free for commercial and non-commercial use as long as
## the following conditions are aheared to.  The following conditions
## apply to all code found in this distribution, be it the RC4, RSA,
## lhash, DES, etc., code; not just the SSL code.  The documentation
## included with this distribution is covered by the same copyright terms
## 
## // Copyright remains Massimiliano Pala's, and as such any Copyright notices
## in the code are not to be removed.
## If this package is used in a product, Massimiliano Pala should be given
## attribution as the author of the parts of the library used.
## This can be in the form of a textual message at program startup or
## in documentation (online or textual) provided with the package.
## 
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions
## are met:
## 1. Redistributions of source code must retain the copyright
##    notice, this list of conditions and the following disclaimer.
## 2. Redistributions in binary form must reproduce the above copyright
##    notice, this list of conditions and the following disclaimer in the
##    documentation and/or other materials provided with the distribution.
## 3. All advertising materials mentioning features or use of this software
##    must display the following acknowledgement:
## //   "This product includes OpenCA software written by Massimiliano Pala
## //    (madwolf@openca.org) and the OpenCA Group (www.openca.org)"
## 4. If you include any Windows specific code (or a derivative thereof) from 
##    some directory (application code) you must include an acknowledgement:
##    "This product includes OpenCA software (www.openca.org)"
##
## THIS SOFTWARE IS PROVIDED BY OPENCA DEVELOPERS ``AS IS'' AND
## ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
## IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
## ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
## FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
## DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
## OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
## HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
## LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
## OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
## SUCH DAMAGE.
##
## The licence and distribution terms for any publically available version or
## derivative of this code cannot be changed.  i.e. this code cannot simply be
## copied and put under another distribution licence
## [including the GNU Public Licence.]
##
## Contributions by:
##          Martin Leung <ccmartin@ust.hk>
##	    Uwe Gansert <ug@suse.de>

##############################################################
##             OpenSSL execution environment                ##
##                        BEGIN                             ##
##############################################################

sub _startShell
{
    my $self = shift;

    my $keys = { @_ };

    return 1 if ($self->{OPENSSL});

    my $open = "| ".$self->{shell}.
               " 1>$self->{tmpDir}/${$}_stdout.log".
               " 2>$self->{tmpDir}/${$}_stderr.log";

    if (not open $self->{OPENSSL}, $open)
    {
      throw EBox::Exceptions::Internal(__x("Cannot start OpenSSL shell. ({errval})", errval => $!));
      return undef;
    }

    return 1;
}

sub _stopShell
{
    my $self = shift;

    return 1 if (not $self->{OPENSSL});

    print {$self->{OPENSSL}} "exit\n";
    close $self->{OPENSSL};
    $self->{OPENSSL} = undef;

    return 1;
}

# Return two values into an array
# (OK or ERROR, output)
sub _executeCommand # (COMMAND, INPUT?, HIDE_OUTPUT?)
{
    my $self = shift;

    my $keys = { @_ };

    ## initialize openssl

    return ("ERROR", "Error starting shell") if (not $self->_startShell());

    ## run command

    my $command = $keys->{COMMAND};
#   EBox::debug("Command: $command") ;

    my $input  = undef;
    $input   = $keys->{INPUT} if (exists $keys->{INPUT});
    $command =~ s/\n*$//;
    $command .= "\n";

    if (not print {$self->{OPENSSL}} $command)
    {
      throw EBox::Exceptions::Internal("Cannot write to the OpenSSL shell. ({errval})", errval => $!);
      return ("ERROR", "Error writing to the shell");
    }


    ## send the input

    if ($input and not print {$self->{OPENSSL}} $input."\x00")
    {

      throw EBox::Exceptions::Internal("Cannot write to the OpenSSL shell. ({errval})", errval => $!);
      return ("ERROR", "Error writing to the shell");
    }

    return ("ERROR", "Error stopping shell") if (not $self->_stopShell());

    ## check for errors

    if (-e "$self->{tmpDir}/${$}_stderr.log")
    {

        ## there was an error
        my $ret = "";
        if (open FD, "$self->{tmpDir}/${$}_stderr.log")
        {
            while( my $tmp = <FD> ) {
	        $ret .= $tmp;
#		EBox::debug( $tmp );
            }
            close(FD);
        }
        unlink ("$self->{tmpDir}/${$}_stderr.log");
        if ($ret =~ /error/i)
        {
            unlink ("$self->{tmpDir}/${$}_stdout.log");
            return ("ERROR", $ret);
        }
    }
    ## load the output

    my $ret = 1;
    if (-e "$self->{tmpDir}/${$}_stdout.log" and
        open FD, "$self->{tmpDir}/${$}_stdout.log")
    {
        ## there was an output
        $ret = "";
        while( my $tmp = <FD> ) {
            $ret .= $tmp;
	  }
        close(FD);
        $ret =~ s/^(OpenSSL>\s)*//s;
        $ret =~ s/OpenSSL>\s$//s;
        $ret = 1 if ($ret eq "");
    }
    unlink ("$self->{tmpDir}/${$}_stdout.log");

    my $msg = $ret;
    $msg = "<NOT LOGGED>" if ($keys->{HIDE_OUTPUT});

    return ("OK", $ret);
}

##############################################################
##                         END                              ##
##             OpenSSL execution environment                ##
##############################################################

##############################################################
# End OpenCA code
##############################################################

1;
