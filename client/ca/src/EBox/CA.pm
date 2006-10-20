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

package EBox::CA;

use strict;
use warnings;

####################################
# Dependencies: File::Slurp package
####################################
use File::Slurp;

use base 'EBox::GConfModule';

use EBox::CA::DN;
use EBox::Gettext;
use EBox::Config;
use EBox;

# FIXME: Put the correct directory, ask
use constant TEMPDIR     => EBox::Config->tmp(); # "/tmp/";
use constant OPENSSLPATH => "/usr/bin/openssl";

use constant CATOPDIR => EBox::Config->locale() . "CA/";
# "/home/quique/my-stuff/openssl-tests/demoCA/";

use constant SSLCONFFILE => EBox::Config->conf() . "openssl.cnf";
# CATOPDIR . "../openssl.cnf";

# All paths related to CATOPDIR
use constant REQDIR      => CATOPDIR . "reqs/";
use constant PRIVDIR     => CATOPDIR . "private/";
use constant CRLDIR      => CATOPDIR . "crl/";
use constant NEWCERTSDIR => CATOPDIR . "newcerts/";
use constant CERTSDIR    => CATOPDIR . "certs/";
# Place to put the public keys
use constant KEYSDIR     => CATOPDIR . "keys/";
use constant CAREQ       => REQDIR . "careq.pem";
use constant CACERT      => CATOPDIR . "cacert.pem";
use constant INDEXFILE   => CATOPDIR . "index.txt";
use constant CRLNOFILE   => CATOPDIR . "crlnumber";

# Keys from CA
use constant CAPRIVKEY   => PRIVDIR . "cakey.pem";
use constant CAPUBKEY    => KEYSDIR . "capubkey.pem";

# Directory and file modes
use constant DIRMODE     => 00700;
use constant FILEMODE    => 00600;

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
  $openssl = "/usr/bin/openssl";
  $ENV{OPENSSL} = $openssl;
}

sub _create
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'ca',
					  domain => 'ebox-ca',
					  @_);

	bless($self, $class);

	# OpenSSL environment stuff
	$self->{tmpDir} = TEMPDIR;
	$self->{shell} = OPENSSLPATH;
	# The CA DN
	$self->{dn} = $self->_obtainDN(CACERT);

	return $self;
}

sub new {

  my $class = shift;
  my $self = {};

  bless($self, $class);

  # OpenSSL environment stuff
  $self->{tmpDir} = TEMPDIR;
  $self->{shell} = OPENSSLPATH;

  # The CA DN
  $self->{dn} = $self->_obtainDN(CACERT);

  return $self;

}

# Method: domain
#
#       Return the gettext domain
#
# Returns:
# 
#       the gettext domain

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
#       True, if the Certification Infrastructure has been
#       created. False, otherwise.

sub isCreated
  {
    return (-d CATOPDIR and -f CACERT and -f CAPRIVKEY
	    and -f CAPUBKEY);
  }
    
# Method: createCA
#
#       Create a Certification Authority with a self-signed certificate
#       and if it not setup, create the directory hierarchy for the CA
#
# Parameters:
#
#       countryName  : country name {2 letter code} (eg, ES) (Optional)
#       stateName     : state or province name (eg, Aragon) (Optional)
#       localityName  : locality name (eg, Zaragoza) (Optional)
#       orgName       : organization name (eg, company name)
#       orgNameUnit  : organizational unit name (eg, section name) (Optional)
#       commonName    : common name from the CA (Optional)
#       caKeyPassword : passphrase for generating keys
#       days         : expire day of self signed certificate (Optional)
#
# Returns:
# 
#       1 OK, undef otherwise

sub createCA {

  my ($self, %args) = @_;

  return undef unless defined( $args{caKeyPassword} );
  return undef unless defined( $args{orgName} );

  if ( ! -d CATOPDIR ) {
    # Create the directory hierchary
    mkdir (CATOPDIR, DIRMODE);
    # Let's assume the subdirectories have the same name
    mkdir (CERTSDIR, DIRMODE);
    mkdir (CRLDIR, DIRMODE);
    mkdir (NEWCERTSDIR, DIRMODE);
    mkdir (KEYSDIR, DIRMODE);
    mkdir (PRIVDIR, DIRMODE);
    mkdir (REQDIR, DIRMODE);
    # Create index and crl number
    open ( my $OUT, ">" . INDEXFILE);
    close ($OUT);
    open ( $OUT, ">" . CATOPDIR . "crlnumber");
    print $OUT "01\n";
    close ($OUT);
  }

  # Save the current CA password for private key
  $self->{caKeyPassword} = $args{caKeyPassword};

  return if (-f CACERT);

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
  if ( $args{days} > 11499 ) {
    $args{days} = 11499;
    # Warning -> Year 2038 Bug
    # http://www.mail-archive.com/openssl-users@openssl.org/msg45886.html
    EBox::warn(__("Days set to the maximum allowed: Year 2038 Bug"));
  }

  # To create the request the distinguished name is needed
  $self->_createRequest(reqFile     => CAREQ,
			genKey      => "1",
			privKey     => CAPRIVKEY,
			keyPassword => $self->{caKeyPassword},
			dn          => $self->{dn}
		       );

  # Sign the selfsign certificate
  $self->_signRequest(userReqFile  => CAREQ,
		      days         => $args{days},
		      userCertFile => CACERT,
		      selfsigned   => "1",
		      createSerial => "1");

  # Generate the public key file
  $self->_getPubKey(CAPRIVKEY,
		    $self->{caKeyPassword},
		    CAPUBKEY);

  #unlink (CAREQ);
  return 1;

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
#
# Returns:
#
#       undef if OK, anything else otherwise
#
# Exceptions:
#
#      External - throw if the certificate doesn't exist

sub revokeCACertificate
  {

    my ($self, %args) = @_;

    # Revoked all issued and valid certificates
    my $listCerts = $self->listCertificates();
    foreach my $element (@{$listCerts}) {
      # Revoked only valid ones
      # We ensure not to revoke the CA cert before the others
      if ($element->{state} eq 'V' and
	  -f ( KEYSDIR . $element->{dn}->dnAttribute('commonName') . ".pem" ) ) {
	
	$self->revokeCertificate(commonName    => $element->{dn}->dnAttribute('commonName'),
				 reason        => "cessationOfOperation",
				 caKeyPassword => $args{caKeyPassword}
				);
	  
	}
    }

    return $self->revokeCertificate(commonName    => "unknown",
				    reason        => $args{reason},
				    caKeyPassword => $args{caKeyPassword},
				    certFile      => CACERT);

  }

# Method: issueCACertificate
#
#       Issue the self-signed CA certificate
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
#       caKeyPassword - key passpharse for CA
#
# Returns:
#
#       the new certificate file path or undef if any error happened
#
# Exceptions:
#
#      External - throw if the CA private key passpharse is NOT
#                 correct

sub issueCACertificate 
  {

    my ($self, %args) = @_;

    return undef unless defined ($args{caKeyPassword});
    return undef unless defined($args{orgName});

    # Define the distinguished name -> default values in configuration file
    $args{commonName} = CA_CN_DEF unless ( $args{commonName} );
    $self->{dn} = EBox::CA::DN->new ( countryName          => $args{countryName},
				      stateName            => $args{stateName},
				      localityName         => $args{localityName},
				      organizationName     => $args{orgName},
				      organizationNameUnit => $args{orgNameUnit},
				      commonName           => $args{commonName});

    return $self->issueCertificate(commonName     => $self->{dn}->dnAttribute('commonName'),
				   countryName    => $self->{dn}->dnAttribute('countryName'),
				   localityName   => $self->{dn}->dnAttribute('localityName'),
				   orgName        => $self->{dn}->dnAttribute('orgName'),
				   orgNameUnit    => $self->{dn}->dnAttribute('orgNameUnit'),
				   keyPassword    => $args{caKeyPassword},
				   days           => $args{days},
				   caKeyPassword  => $args{caKeyPassword},
				   privateKeyFile => CAPRIVKEY,
				   requestFile    => CAREQ,
				   certFile       => CACERT);

  }

# Method: renewCACertificate
#
#       Renew the self-signed CA certificate. Re-signs all the issued
#       certificates with the same expiration date.
#
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
#       caKeyPassword - key passpharse for CA (Optional)
#
# Returns:
#
#       the new certificate file path or undef if any error happened
#
# Exceptions:
#
#      External - throw if the CA private key passpharse is NOT
#                 correct

sub renewCACertificate
  {
    my ($self, %args) = @_;

    if ( not defined($args{caKeyPassword}) and
	 not defined($self->{caKeyPassword})) {
      throw EBox::Exceptions::External(__('No CA private key password is given'));
      # print STDERR "No CA private key password is given\n";
      return undef;
    }

    if (not defined($self->{caKeyPassword}) ) {
      $self->{caKeyPassword} = $args{caKeyPassword};
    }

    $args{caKeyPassword} = $self->{caKeyPassword}
      unless ($args{caKeyPassword});

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
					       overwrite     => "1");

    # Re-signs all the issued certificates with the same expiry date
    foreach my $element (@{$listCerts}) {
      # Renew the previous ones that remains valid
      if ($element->{state} eq 'V' and
	  -f ( KEYSDIR . $element->{dn}->dnAttribute('commonName') . ".pem") ) {
	$self->renewCertificate( commonName    => $element->{dn}->dnAttribute('commonName'),
				 endDate       => $element->{expiryDate},
				 caKeyPassword => $args{caKeyPassword}
			       );

      }
    }

    return $renewedCert;

  }

# Method: CAPublicKey
#
#       Return the public key from the Certificate Authority
#
# Parameters:
#
#       caKeyPassword : the passphrase to access to private key
#       (Optional)
#
# Returns:
#
#       Path to the file which contains the CA Public Key in
#       PEM format or undef if it was not possible to create
#
# Exceptions:
#
#       Internal - If the directory creation is not possible

sub CAPublicKey {

  my ($self, $caKeyPassword) = @_;

  if (-f CAPUBKEY) {
    return CAPUBKEY;
  }

  # If does NOT exist, we have to generate it
  $caKeyPassword = $self->{caKeyPassword}
    unless ( defined ($caKeyPassword) );

  return $self->_getPubKey(CAPRIVKEY, $caKeyPassword, CAPUBKEY);

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
#       keyPassword - passphrase for the private key
#       days - expiration days of certificate (Optional)
#              Only valid if endDate is not present
#       endDate - explicity expiration date (Optional)
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
#       Path where the certificate is left or undef if problem has
#       happened 
#
# Exceptions:
# 
#       External - throw if the CA passpharse CANNOT be located
#

sub issueCertificate {

  my ($self, %args) = @_;

  # Treat arguments

  return undef unless (defined($args{commonName}));
  return undef unless (defined($args{keyPassword}));

  my $days;
  if (not defined($args{endDate}) ) {
    $days = $args{days};
    $days = 365 unless $days;
    if ( $days > 11499 ) {
      $days = 11499;
      # Warning -> Year 2038 Bug
      # http://www.mail-archive.com/openssl-users@openssl.org/msg45886.html
      EBox::warn(__("Days set to the maximum allowed: Year 2038 Bug"));
    }
  }

  if ( defined($args{caKeyPassword}) and not defined($self->{caKeyPassword})) {
    $self->{caKeyPassword} = $args{caKeyPassword};
  }

  if (not defined($self->{caKeyPassword}) ) {
    throw EBox::Exceptions::External(__('No CA passpharse to sign a new certificate')); 
    # print STDERR "No CA passpharse to sign a new certificate\n";
    return undef;
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
  my $dn = $self->{dn}->copy();
  $dn->dnAttribute("countryName", $args{countryName})
    if (defined($args{countryName}));
  $dn->dnAttribute("stateName", $args{stateName})
    if (defined($args{stateName}));
  $dn->dnAttribute("localityName", $args{localityName})
    if (defined($args{localityName}));
  $dn->dnAttribute("orgName", $args{orgName})
    if (defined($args{orgName}));
  $dn->dnAttribute("orgNameUnit", $args{orgNameUnit})
    if (defined($args{orgNameUnit}));
  $dn->dnAttribute("commonName", $args{commonName})
    if (defined($args{commonName}));

  # Create the certificate request
  my $genKey = "1";
  if ( defined($args{privateKeyFile} )) {
    if (not -f $args{privateKeyFile} ) {
      # print STDERR "Not $args{privateKeyFile} found\n";
      throw EBox::Exceptions::External(__x("Private key file {file} does NOT exist", 
					   file => $args{privateKeyFile}));
      return undef;
    }
    $genKey = "0";
  }
  $self->_createRequest(reqFile     => $userReq,
			genKey      => $genKey,
			privKey     => $privKey,
			keyPassword => $args{keyPassword},
			dn          => $dn
		       );

  # Signs the request
  my $selfSigned = "0";
  if ( defined ($certFile) ) {
    $selfSigned = $certFile eq CACERT;
  }
  my $output = $self->_signRequest( userReqFile  => $userReq,
				    days         => $days,
				    userCertFile => $certFile,
				    selfsigned   => $selfSigned,
				    endDate      => $args{endDate}
				  );

  # Generate the public key file (if it is a newly created private
  # key)
  if (not defined($args{privateKeyFile}) ) {
    my $result = $self->_getPubKey($privKey, 
				   $args{keyPassword},
				   $pubKey);
  }

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
#
# Returns:
#
#       undef if OK, anything else otherwise
#
# Exceptions:
#
#      External - throw if the certificate does NOT exist
#                 or the reason is NOT a standard one
#                 or the CA passpharse CANNOT be located
#
sub revokeCertificate {

  my ($self, %args) = @_;
  my $commonName = $args{commonName};
  my $reason = $args{reason};
  my $caKeyPassword = $args{caKeyPassword};
  my $certFile = $args{certFile};

  return "No common name is given" unless defined($commonName);

  my @reasons = qw(unspecified keyCompromise CACompromise affiliationChanged superseeded cessationOfOperation certificationHold);

  if ( defined($caKeyPassword) and not defined($self->{caKeyPassword})) {
    $self->{caKeyPassword} = $caKeyPassword;
  }

  if ( not defined($self->{caKeyPassword}) ) {
    throw EBox::Exceptions::External(__('No CA passpharse is given to revoke')); 
    # return 'No CA passpharse is given to revoke';
  }

  # RFC 3280 suggests not to use an unspecified reason when the reason
  # is unknown.
  # $reason = "unspecified" unless defined($reason);

  $certFile = $self->_findCertFile($commonName) unless defined ($certFile);

  throw EBox::Exceptions::External(__x("Certificate with common name {commonName} does NOT exist", 
				       commonName => $commonName))
    unless -f $certFile;
  
  throw EBox::Exceptions::External(__x("Reason {reason} is not an applicable reason.\n"
				       . "Options:" . @reasons, reason => $reason))
    unless $self->_isIn(\@reasons, $reason);

  # TODO: Different kinds of revokations (CACompromise,
  # keyCompromise...) 
  # We can set different arguments regard to revocation reason
  my $cmd = "ca";
  $self->_commonArgs("ca", \$cmd);
  $cmd .= "-revoke $certFile -passin env:PASS ";
  $cmd .= "-crl_reason $reason " if (defined($reason));

  # Tell openssl to revoke
  $ENV{'PASS'} = $self->{caKeyPassword};
  my $ret = $self->_executeCommand(COMMAND => $cmd);
  delete ($ENV{'PASS'});

  # If any error is shown from revocation, the result is got back
  return $ret if ($ret ne "1");

  # Generate a new Certification Revocation List (For now in the same
  # method...)

  # Localtime -> module NTP
  (my $day, my $month, my $year) = (localtime)[3..5];

  my $date = sprintf("%04d-%02d-%02d", $year+1900, $month+1, $day);
  
  $cmd= "ca";
  $self->_commonArgs("ca", \$cmd);
  $cmd .= "-gencrl -passin env:PASS ";
  $cmd .= "-out " . CRLDIR . $date . "_crl.pem";

  $ENV{'PASS'} = $self->{caKeyPassword};
  $self->_executeCommand(COMMAND => $cmd);
  delete ($ENV{'PASS'});

  return undef;

}

# Method: listCertificates
#
#       List the certificates that are ready on the system
#       or only one if the serial parameter is provided
#
# Parameters:
#
#       cn - Common Name to list a certificate metadata 
#            from a particular user
#
# Returns:
#
#       A reference to an array containing hashes which the following
#       elements:
#
#       dn - an EBox::CA::DN object
#       state - 'V' from Valid, 'R' from Revoked or 'E' from Expired
#       expiryDate - the expiry date in a Date hash if state valid
#
#       revokeDate - the revocation date in a Date hash if state is
#                    revoked 
#       reason     - reason to revoke if state is revoked
#
sub listCertificates {

  my $self = shift;

  my $cnToSearch = shift;

  my @lines = read_file( INDEXFILE );
  my @out = ();

  foreach ( @lines ) {
    my @line = split(/\t/);

    my %element;
    $element{'state'} = $line[STATE_IDX];
    if ($element{'state'} eq 'V') {
      $element{'expiryDate'} = $self->_parseDate($line[EXPIRE_DATE_IDX]);
    } else {
      my $field = $line[REV_DATE_REASON_IDX];
      my ($revDate, $reason) = split(',', $field);
      $element{'revokeDate'} = $self->_parseDate($revDate);
      $element{'reason'} = $reason;
    }
    $element{'dn'} = EBox::CA::DN->parseDN($line[SUBJECT_IDX]);

    if( defined($cnToSearch) ) {
      if ($element{'dn'}->dnAttribute('commonName') eq $cnToSearch) {
	push (@out, \%element);
	last; # The last iteration
      }
    } else {
      push (@out, \%element);
    }
  }

  return \@out;
  
}

# Method: getKeys
#
#       Get the keys (public and private) from CA given an specific user.
#       Remove the private key from eBox.
#
# Parameters:
#
#       commonName - the common name to identify the key
#
# Returns:
#
#       a reference to a hash containing the public and private key file
#       paths (privateKey and publicKey) stored in PEM format
#
# Exceptions:
#
#      External - throw if the keys do NOT exist
#                 
sub getKeys {

  my ($self, $commonName) = @_;

  return undef unless defined ($commonName);

  my %keys;

  if (-f PRIVDIR . "$commonName.pem" ) {
    $keys{privateKey} = PRIVDIR . "$commonName.pem";
  } else {
    $keys{privateKey} = undef;
  }

  $keys{publicKey} = KEYSDIR . "$commonName.pem";

  throw EBox::Exceptions::External(__x("The user {commonName} does NOT exist",
				      commonName => $commonName))
    unless (-f $keys{publicKey});

  # FIXME: Remove private key when the CGI has sent the private key
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
# Exceptions:
#
#      External - throw if the private key does NOT exist
sub removePrivateKey
  {
    my ($self, $commonName) = @_;

    return undef unless defined ($commonName);

    if (-f PRIVDIR . "$commonName.pem" ) {
      unlink (PRIVDIR . "$commonName.pem");
    } else {
      throw EBox::Exceptions::External(__x('Private key from {commonName} does NOT exist'
					   , commonName => $commonName));
      # print STDERR "Private key from $commonName does NOT exist";
    }
    return;

  }

# Method: renewCertificate
#
#       Renew a certificate from a user.
#       If any Distinguished Name is needed to change, it is done.
#
# Parameters:
#
#       commonName - the common name from the user. Not needed
#                    if a certificate file is given (Optional)
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
#                 Only if enddate not appeared
#       caKeyPassword - key passpharse for CA (Optional)
#       certFile - the certificate file to renew (Optional)
#       reqFile  - the request certificate file which to renew (Optional)
#
#       privateKeyFile - the private key file (Optional)
#       keyPassword - the private key passpharse. Only necessary when
#       a new request is issued (Optional) 
#
#       overwrite - overwrite the current certificate file. Only if
#       the certFile is passed (Optional)
#
# Returns:
#
#       the new certificate file path or undef if it is not possible
#
# Exceptions:
#
#      External - throw if the user does NOT exist
#                 or the CA passpharse CANNOT be located
#                 or the user passpharse is needed and it's NOT present

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

    return undef unless defined ($args{commonName})
      or defined ($args{certFile});

    if ( defined($args{caKeyPassword}) and not defined($self->{caKeyPassword})) {
      $self->{caKeyPassword} = $args{caKeyPassword};
    }

    if ( not defined($self->{caKeyPassword}) ) {
      throw EBox::Exceptions::External(__('No CA passpharse is given to revoke')); 
      #return undef;
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

    my $userDN = $self->_obtainDN($userCertFile);

    my $dnFieldHasChanged = '0';
    if ( defined($args{countryName})
	 and $args{countryName} ne $userDN->dnAttribute('countryName')) {
      $dnFieldHasChanged = "1";
      $userDN->dnAttribute('countryName', $args{countryName});
    }
    if (defined($args{stateName}) 
	and $args{stateName} ne $userDN->dnAttribute('stateName')) {
      $dnFieldHasChanged = "1" ;
      $userDN->dnAttribute('stateName', $args{stateName});
    }
    if (defined($args{localityName})
	and $args{localityName} ne $userDN->dnAttribute('localityName')) {
      $dnFieldHasChanged = "1" ;
      $userDN->dnAttribute('localityName', $args{localityName});
    }
    if (defined($args{orgName})
	and $args{orgName} ne $userDN->dnAttribute('orgName')) {
      $dnFieldHasChanged = "1" ;
      $userDN->dnAttribute('orgName', $args{orgName});
    }
    if (defined($args{orgNameUnit})
	and $args{orgNameUnit} ne $userDN->dnAttribute('orgNameUnit')) {
      $dnFieldHasChanged = "1" ;
      $userDN->dnAttribute('orgNameUnit', $args{orgNameUnit});
    }

    # Revoke old certificate
    my $retVal = $self->revokeCertificate(commonName    => $userDN->dnAttribute('commonName'),
					  reason        => "superseded",
					  certFile      => $userCertFile,
					  caKeyPassword => $args{caKeyPassword});

    if (defined($retVal) ) {
      throw EBox::Exceptions::External(__x("Common name {cn} does NOT exist in this CA"
					   , cn => $userDN->dnAttribute('commonName')));
      #print STDERR "error revoking. Reason: $retVal\n";
      #return undef;
    }
    # Sign a new one
    my $userReq;
    if ( defined($args{reqFile}) ) {
      $userReq = $args{reqFile};
    } else {
      $userReq = REQDIR . $userDN->dnAttribute('commonName') . ".pem";
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
      }

      $self->_signRequest( userReqFile  => $userReq,
			   days         => $args{days},
			   userCertFile => $newCertFile,
			   selfsigned   => $selfsigned,
			   createSerial => "0",
			   newSubject   => $newSubject,
			   endDate      => $args{endDate}
			 );

    } else {
      # If we don't keep the request, we should create a new one with
      # the private key if exists. If not, we need to recreate all...
      # by using issuing a new certificate with a new request
      my $privKeyFile = PRIVDIR . $userDN->dnAttribute('commonName') . ".pem";
      $privKeyFile = $args{privateKeyFile} if ($args{privateKeyFile});
      if ( not defined($args{keyPassword}) ) {
	# print STDERR "The private key passpharse is needed. No
	#  renewal was made."  . "Call issueCertificate to create a
	#  new certificate with new keys\n"; 
	throw EBox::Exceptions::External("The private key passpharse" . 
					 "is needed to create a new " .
					 "request. No renewal was made. " .
					 "Issue a new certificate with " .
					 "new keys");
	# return undef;
      }

      $self->issueCertificate( countryName  => $userDN->dnAttribute('countryName'),
			       stateName    => $userDN->dnAttribute('stateName'),
			       localityName => $userDN->dnAttribute('localityName'),
			       orgName      => $userDN->dnAttribute('orgName'),
			       orgNameUnit  => $userDN->dnAttribute('orgNameUnit'),
			       commonName   => $userDN->dnAttribute('commonName'),
			       keyPassword  => $args{keyPassword},
			       days         => $args{days},
			       privateKeyFile => $privKeyFile,
			       requestFile    => $userReq,
			       certFile       => $newCertFile,
			       endDate        => $args{endDate});
    }

    if (not defined($newCertFile) ) {
      $newCertFile = $self->_findCertFile($userDN->dnAttribute('commonName'));
    }

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
# Exceptions:
#
#      External - throw if the passpharse is incorrect

sub updateDB
  {

    my ($self, %args) = @_;

    # Manage the parameters
    my $caKeyPassword = $args{caKeyPassword};

    if ( defined($caKeyPassword) and not defined($self->{caKeyPassword})) {
      $self->{caKeyPassword} = $caKeyPassword;
    }
    
    my $cmd = "ca ";
    $cmd .= "-updatedb ";
    $self->_commonArgs("ca", \$cmd);
    $cmd .= "-passin env:PASS ";

    $ENV{'PASS'} = $self->{caKeyPassword};
    my $ret = $self->_executeCommand( COMMAND => $cmd );
    delete( $ENV{'PASS'} );

    if ($ret ne "1") {
      throw EBox::Exceptions::External(__("The CA key passpharse is incorrect"));
    }

  }

# _regenConfig is not longer needed 'cause this module doesn't manage a daemon

# The method summary is not neccessary since it is not a network service

# Method: menu
#
#       Add text area module to eBox menu
#
# Parameters:
#
#       root - the EBox::Menu::Root where to leave our items
#

sub menu {

  my ($self, $root) = @_;

#  my $folder = new EBox::Menu::Folder('name' => 'Certificate Authority Manager',
#				      'text' => __('Certificate Authority Manager')
#				     );
#  $folder->add(new EBox::Menu::Item('url' => 'ca/CAInfo',
#				    'text' => __('Certificate Authority')
#				   ));
#
#  $folder->add(new EBox::Menu::Item('url' => 'ca/CertManagement',
#				    'text' => __('Certificate Management')
#				    ));
#
  $root->add(new EBox::Menu::Itme('url'  => 'ca/Index',
				  'text' => __('Certificate Manager')));

}

# Check if an element is in an array
sub _isIn # (array, element)
{

  my ($self, $array, $element) = @_;

  foreach (@{$array}) {
    return "1" if ($element eq $_);
  }

  return "0";

}

# Obtain the public key given the private key 
#
# Return public key path if it is correct or undef if password is
# incorrect

sub _getPubKey # (privKeyFile, password, pubKeyFile)
  {
    my ($self, $privKeyFile, $password, $pubKeyFile)  = @_;
    # TODO: Check the password is correct

    return undef unless (defined($password));

    $pubKeyFile = TEMPDIR . "pubKey.pem" unless (defined ($pubKeyFile));
    
    my $cmd = "rsa ";
    $cmd .= "-in $privKeyFile -out $pubKeyFile";
    $cmd .= " -outform PEM -pubout -passin env:PASS";

    $ENV{'PASS'} = $password;
    my $ret = $self->_executeCommand(COMMAND => $cmd);
    delete( $ENV{'PASS'} );

    # TODO : Check the output from openssl

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
	$found = $subject->dnAttribute("commonName") eq $commonName;
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
# *: Optional

sub _createRequest # (reqFile, genKey, privKey, keyPassword, dn)
  {

    my ($self, %args) = @_;

    # To create the request the distinguished name is needed
    my $cmd = "req";
    $self->_commonArgs("req", \$cmd);
    
    $cmd .= "-new ";
    $self->_commonArgs("req", \$cmd);
    if ($args{genKey}) {
      $cmd .= "-keyout $args{privKey} ";
      $cmd .= "-passout env:PASS ";
    } else {
      $cmd .= "-key $args{privKey} ";
      $cmd .= "-passin env:PASS ";
    }

    $cmd .= "-out $args{reqFile} ";
    $cmd .= "-subj \"". $args{dn}->stringOpenSSLStyle() . "\" ";
    $cmd .= "-multivalue-rdn " if ( $args{dn}->stringOpenSSLStyle() =~ /[^\\](\\\\)*\+/);

    # We have to define the environment variable PASS to pass the
    # password
    $ENV{'PASS'} = $args{keyPassword};
    # Execute the command
    my $ret = $self->_executeCommand(COMMAND => $cmd);
    delete( $ENV{'PASS'} );

    return;

  }

# Sign a request
# returns the certificate in text format
# * Optional Parameter
sub _signRequest # (userReqFile, days, userCertFile*, policy*, selfsigned*,
                 # createSerial*, newSubject*, endDate*)
  {

    my ($self, %args) = @_;
    
    my $policy = "policy_anything" unless (defined($args{policy}));

    my $endDate = $self->_flatDate($args{endDate}) if defined($args{endDate});

    # Sign the request
    my $cmd = "ca";
    $self->_commonArgs("ca", \$cmd);
    $cmd .= "-create_serial "if ($args{createSerial});
    $cmd .= "-passin env:PASS ";
    $cmd .= "-outdir " . CERTSDIR . " ";
    $cmd .= "-out $args{userCertFile} " if defined($args{userCertFile});
    $cmd .= "-extensions v3_ca " if ( EXTENSIONS_V3);
    $cmd .= "-selfsign " if ($args{selfsigned});
    $cmd .= "-policy $policy ";
    $cmd .= "-days $args{days} " if defined($args{days});
    $cmd .= "-enddate $endDate " if defined($args{endDate});
    if ( defined($args{newSubject}) ) {
      $cmd .= "-subj \"". $args{newSubject}->stringOpenSSLStyle() . "\" ";
      $cmd .= "-multivalue-rdn " if ( $args{newSubject}->stringOpenSSLStyle() =~ /[^\\](\\\\)*\+/);
    }
    $cmd .= "-infiles $args{userReqFile}";

    $ENV{'PASS'} = $self->{caKeyPassword};
    my $output = $self->_executeCommand(COMMAND => $cmd);
    delete ( $ENV{'PASS'} );

    return $output;

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

# Given a certification file
# Obtain the EBox::CA::DN object or undef if no such file
sub _obtainDN # (certFile)
  {

    my ($self, $certFile) = @_;

    if (not -f $certFile) {
      return undef;
    }

    my $cmd = "x509 -subject -in $certFile -noout";

    my $ret = $self->_executeCommand(COMMAND => $cmd);

    # Returns a subject = something
    # Remove the "subject= " part
    $ret =~ s/^subject= //g;

    return EBox::CA::DN->parseDN($ret);

  }

# Given the string date from index.txt file
# obtain the date as a Date hash.

sub _parseDate
  {
    my ($self, $str) = @_;

    my ($y,$mon,$mday,$h,$m,$s) = $str =~ /([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})Z$/;

    $y += 2000;
	# my $wday = Day_of_Week($y+1999,$mon,$mday);

    my %date = ( "second" => $s,
		 "minute" => $m,
		 "hour"   => $h,
		 "day"    => $mday,
		 "month"  => $mon,
		 "year"   => $y);
    return \%date;
  }

# A private method to flat a Date hash to a OpenSSL form like
# YYMMDDHHMMSSZ 
sub _flatDate # (date)
  {
    my ($self, $date) = @_;

    my $dateStr =sprintf("%02d%02d%02d%02d%02d%02dZ",
			 $date->{year} - 2000,
			 $date->{month},
			 $date->{day},
			 $date->{hour},
			 $date->{minute},
			 $date->{second});

    print "\ndateStr: $dateStr\n";

    return $dateStr;

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

sub _executeCommand # (COMMAND, INPUT, HIDE_OUTPUT)
{
    my $self = shift;

    my $keys = { @_ };

    ## initialize openssl

    return undef if (not $self->_startShell());

    ## run command

    my $command = $keys->{COMMAND};
    print "Command: $command\n";

    my $input  = undef;
    $input   = $keys->{INPUT} if (exists $keys->{INPUT});
    $command =~ s/\n*$//;
    $command .= "\n";

    if (not print {$self->{OPENSSL}} $command)
    {
      throw EBox::Exceptions::Internal("Cannot write to the OpenSSL shell. ({errval})", errval => $!);
      return undef;
    }


    ## send the input

    if ($input and not print {$self->{OPENSSL}} $input."\x00")
    {

      throw EBox::Exceptions::Internal("Cannot write to the OpenSSL shell. ({errval})", errval => $!);
      return undef;
    }

    return undef if (not $self->_stopShell());

    ## check for errors

    if (-e "$self->{tmpDir}/${$}_stderr.log")
    {

        ## there was an error
        my $ret = "";
        if (open FD, "$self->{tmpDir}/${$}_stderr.log")
        {
            while( my $tmp = <FD> ) {
                $ret .= $tmp;
		print $tmp;
            }
            close(FD);
        }

        unlink ("$self->{tmpDir}/${$}_stderr.log");
        if ($ret =~ /error/i)
        {
            unlink ("$self->{tmpDir}/${$}_stdout.log");
            return undef;
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

    return $ret;
}

##############################################################
##                         END                              ##
##             OpenSSL execution environment                ##
##############################################################

##############################################################
# End OpenCA code
##############################################################

1;
