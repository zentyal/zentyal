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

package EBox::ControlCenter::RemoteEBoxProxy;

# Class: EBox::ControlCenter::RemoteEBoxProxy
#
#   It represents a remote eBox. It also returns the current list of
#   eBoxes and get a one created. Currently, it's not possible to
#   join/quit an eBox from this interface. You should use
#   *joinEBox.pl* and *quitEBox.pl* instead.

# Core modules
use Error qw(:try);

#################
# Dependencies
#################
use SOAP::Lite;

# EBox modules
use EBox::Exceptions;
use EBox::ControlCenter::FileEBoxDB;
use EBox::ControlCenter::Common;

# Constants
use constant SOAP_SERVER_PORT => 4430;

# Group: Class Methods

# Method: ListNames
#
#     List the current eBoxes which are depending on this control
#     center. *(Class Method)*
#
# Returns:
#
#     array ref - list containing the common names which currently are
#     attached to this control center
#
sub ListNames
  {

      my ($class) = @_;

      my $fileDB = new EBox::ControlCenter::FileEBoxDB();

      return $fileDB->listEBoxes();

  }

# Method: GetEBoxByName
#
#      Get the RemoteEBoxProxy which represents an eBox attached to
#      this control center given its common name. *(Class method)*
#
# Parameters:
#
#      eBoxName - String the common name which is known the eBox
#      within the control center realm
#
#      readOnly - boolean indicating if the retrieved eBox is in
#      read only mode *(Optional)*
#
# Returns:
#
#      <EBox::ControlCenter::RemoteEBoxProxy> - the remote proxy to
#      send information to eBox
#
# Exceptions:
#
#      <EBox::Exceptions::DataNotFound> - if the common name given is
#      not within the control center realm
#
sub GetEBoxByName
  {

      my ($class, $eBoxName, $readOnly) = @_;

      my $fileDB = new EBox::ControlCenter::FileEBoxDB();

      my $eBoxMetadata_ref = $fileDB->findEBox($eBoxName);
      unless ( defined ( $eBoxMetadata_ref )) {
          throw EBox::Exceptions::DataNotFound( data => __("eBox's name"),
                                                value => $eBoxName);
      }

      my $remoteProxy = $class->_new($eBoxMetadata_ref, $readOnly);

      return $remoteProxy;

  }

# Group: Instance methods

# Method: isReadOnly
#
#       Check if the current eBox is in read only mode
#
# Returns:
#
#       boolean - check whether eBox is read only or not
#
sub isReadOnly
  {

      my ($self) = @_;

      return $self->{'readOnly'};

  }

# Method: modNames
#
#       Retrieve the current modules are installed in this eBox
#
# Returns:
#
#       array ref - the list with the current installed modules
#
sub modNames
  {

      my ($self) = @_;

      return $self->_callSOAP('modNames');

  }

# Method: modExists
#
#       Check if the given module is already installed in eBox
#
# Parameters:
#
#       modName - String the module name to check
#
# Returns:
#
#       boolean - check whether eBox is read only or not
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#       paraemter is missing
#
sub modExists
  {

      my ($self, $modName) = @_;

      defined ( $modName ) or
        throw EBox::Exceptions::MissingArgument('modName');

      return $self->_callSOAP('modExists', $modName);

  }

# Method: modMethod
#
#       Run a public method from an eBox module. The checks are done
#       in server side
#
# Parameters:
#
#       module - String the module to run a method
#       nameMethod - String the method name
#       parameters - an array with the parameters
#
# Returns:
#
#       the result given by the module method
#
# Exceptions:
#
#       Any exception from <EBox::Exceptions> can be thrown
#
sub modMethod
  {

      my ($self, $module, $nameMethod, @params) = @_;

      defined ( $module ) or
        throw EBox::Exceptions::MissingArgument('module');
      defined ( $nameMethod ) or
        throw EBox::Exceptions::MissingArgument('nameMethod');

      my $result = $self->_callSOAP('modMethod', $module, $nameMethod, @params);
      return $result;
  }

# Group: Private methods

# Constructor: _new
#
#       Create an<EBox::ControlCenter::RemoteEBoxProxy> object
#
# Parameters:
#
#       eBoxMetadata_ref - hash ref containing all the metadata stored
#       for this eBox. Check
#       <EBox::ControlCenter::AbstractEBoxDB::storeEBox> to get known
#       the fields which stored
#
#       readOnly - boolean indicating if the retrieved eBox is in read
#       only mode *(Optional)*
#
# Returns:
#
#     <EBox::ControlCenter::RemoteEBoxProxy> - the recently created
#     object
#

sub _new
  {

      my ($class, $eBoxMetadata_ref, $readOnly) = @_;

      my $self = {};
      bless ($self, $class);

      # Store data cacheable
      $self->{readOnly} = $readOnly;

      # Store the data within the object
      $self->{serialNumber} = $eBoxMetadata_ref->{serialNumber};
      $self->{commonName} = $eBoxMetadata_ref->{commonName};
      $self->{eBoxIP} = $eBoxMetadata_ref->{clientIP};

      # Get the certificate and keys path
      my $certDir = EBox::ControlCenter::Common::CACertDir();
      my $keyDir = EBox::ControlCenter::Common::CAPrivateDir();

      $self->{certFile} = EBox::ControlCenter::Common::findCertFile(
         EBox::ControlCenter::Common::controlCenterCN()
                                                                   );
      $self->{keyFile} = $keyDir . '/' .
        EBox::ControlCenter::Common::controlCenterCN() . '.pem';

      $self->{caCertFile} = EBox::ControlCenter::Common::CACert();

      # Create the connection to this eBox
      $self->{soapConnection} = new SOAP::Lite
        uri => 'http://ebox-platform.com/EBox/SOAP/Global',
        proxy => 'https://' . $self->{eBoxIP} . ':' . SOAP_SERVER_PORT . '/soap',
        on_fault => sub {
            my ($soap, $res) = @_;
#            use Data::Dumper;
#            print STDERR 'soap: ' . Dumper($soap) . ' res: ' . Dumper($res);
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
            } else {
                throw EBox::Exceptions::Protocol($soap->transport()->status());
            }
        }
          ;

      # Before calling the remote global, set the certs to Crpyt::SSLeay
      $self->_setCerts();

      # Instance the Global object remotely
      $self->{remGlobal} = $self->{soapConnection}->call(new => ($readOnly))->result();

      return $self;

  }

# Method: _setCerts
#
#       Set the environment variables to do the SOAP call through
#       <Crpyt::SSLeay> library
#
sub _setCerts
  {

      my ($self) = @_;

      $ENV{HTTPS_CERT_FILE} = $self->{certFile};
      $ENV{HTTPS_KEY_FILE} = $self->{keyFile};
      $ENV{HTTPS_CA_FILE} = $self->{caCertFile};
      $ENV{HTTPS_VERSION} = '3';

  }

# Method: _callSOAP
#
#     Encapsulate the SOAP calling since it's currently not possible
#     to use autodispatch.
#
# Parameters:
#
#     methodName - the SOAP method to call
#     params - array with the parameters to the SOAP call
#
# Returns:
#
#     the result given by the methodName with the given params
#
sub _callSOAP
  {

      my ($self, $methodName, @params) = @_;

      my $response = $self->{soapConnection}->$methodName($self->{remGlobal},
                                                          @params);
      return $response->result();

  }

1;
