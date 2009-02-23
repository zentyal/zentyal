# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::RemoteServices::SOAPClient;

# Class: EBox::RemoteServices::SOAPClient
#
#     This package is used as a wrapper to <SOAP::Lite> package to
#     easily manage the SOAP connections using SSL
#

use warnings;
use strict;

use EBox;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Protocol;
use Error qw(:try);
use SOAP::Lite;

# Group: Public functions

# Function: instance
#
#      Wrapper constructor for <SOAP::Lite>
#
# Parameters:
#
#      name - String the service to ask for
#
#      proxy - String the URL to where ask for the name web service
#
#      certs - hash ref containing the following file paths:
#              cert - String the certificate from the client
#              key  - String the private key from the client
#              ca   - String the Certification Authority
#
#      *(Optional)* If not given, the connection is done without
#      credentials
#
# Example:
#
#       new(name  => 'urn:EBox/Services/CA',
#           proxy => 'https://ca.internal.ebox-services.com/soap',
#           certs => { cert => 'cert.pem',
#                      private => 'privKey.pem',
#                      ca   => 'cacert.pem'});
#
# Returns:
#
#       <SOAP::Lite> - the instanced object which has established the
#       connection
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#       argument is missing
#
sub instance
{
    my ($class, %params) = @_;

    unless ( defined ( $params{name} )) {
        throw EBox::Exceptions::MissingArgument('name');
    }
    unless ( defined ( $params{proxy} )) {
        throw EBox::Exceptions::MissingArgument('proxy');
    }

    if ( $params{proxy} =~ m/^https/
         and not defined( $params{certs} )) {
        EBox::warn('Doing connection to web service: '
                   . "$params{name} without credentials to $params{proxy}");
    }

    my $soapConn = new SOAP::Lite(
      uri   => $params{name},
      proxy => $params{proxy},
      on_fault => sub {
          my ($soap, $res) = @_;
          if ( ref $res ) {
              # Get the exception type
              use Data::Dumper;
#              EBox::debug($soap->fault());
#              EBox::debug($res);
#              my $excType = (keys %{$res->faultdetail()})[0];
#              # Get the hash to bless
#              my $hash_ref = $res->faultdetail()->{$excType};
#              # Substitution from __ to ::
#              $excType =~ s/__/::/g;
#              # Do the blessing to have the exception object
#              bless ( $hash_ref, $excType );
#              throw $hash_ref;
          } else {
              throw EBox::Exceptions::Protocol($soap->transport()->status(), '');
          }}
        );

    if ( defined ( $params{certs} )) {
        $class->_setCerts($params{certs});
    }

    my $self = { soapConn => $soapConn };

    bless ( $self, $class );

    return $self;

}

sub DESTROY { ; };

# Method: AUTOLOAD
#
#    Launch every autoload method with the SOAP::Lite object to catch
#    the exceptions to launch them
#
# Returns:
#
#    returnedValue - the returned value given by the external code
#    server
#
sub AUTOLOAD
{
    my ($self, @params) = @_;

    my $methodName = our $AUTOLOAD;

    $methodName =~ s/.*:://;

    if ( $methodName =~ m/^_/ ) {
        throw EBox::Exceptions::Internal('Cannot call a private method');
    }

    # Transform every given param into a SOAP::Data if it is not yet.
    # This assumes all parameters are named
    my @soapParams = ();
    my $even = @params % 2 == 0;
    for(my $i = 0; $i < @params; $i++) {
        my $param = $params[$i];
        if (defined(ref($param)) and ref($param) eq 'SOAP::Data') {
            push(@soapParams, $param);
        } else {
            # This won't work with the special 2 parameters case
            if ( $even ) {
                push(@soapParams, SOAP::Data->name($param, $params[$i+1]));
                $i++;
            } else {
                push(@soapParams, SOAP::Data->value($param));
            }
        }
    }


    my $response = $self->{soapConn}->call($methodName => @soapParams);

    if ( $response->fault() ) {
        if ( defined ( $response->faultdetail() )) {
            # Get the exception type with the hash ref from the first
            # element in hash (An element is expected)
            my ($excType, $excObj) = (each %{$response->faultdetail()});
            # Subtitute from __ to ::
            $excType =~ s/__/::/g;
            # Do the blessing to throw the exception
            bless ( $excObj, $excType );
            throw $excObj;
        }
        if ( $response->faultcode() eq 'soap:Server' ) {
            throw EBox::Exceptions::Internal('Server side: '
                                             . $response->faultstring());
        } elsif ( $response->faultcode() eq 'soap:Client' ) {
            throw EBox::Exceptions::Internal('Client side: '
                                             . $response->faultstring());
        }
    }

    return $response->paramsall();

}

# Group: Private functions

# Set the certificates enviroment variables to establish SSL
# connection
sub _setCerts
{

    my ($class, $certs) = @_;

    $ENV{HTTPS_CERT_FILE} = $certs->{cert};
    $ENV{HTTPS_KEY_FILE} = $certs->{private};
    $ENV{HTTPS_CA_FILE} = $certs->{ca};
    $ENV{HTTPS_VERSION} = '3';
}

1;
