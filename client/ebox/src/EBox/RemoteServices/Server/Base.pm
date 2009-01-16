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

# Class: EBox::RemoteServices::Server::Base
#
#      This base class must be inherited from every Web Service Perl
#      class to have all helper methods here.
#
#      All methods may receive a <SOAP::SOM> as last parameter
#

package EBox::RemoteServices::Server::Base;

use warnings;
use strict;

use vars qw(@ISA);
@ISA=qw(SOAP::Server::Parameters);

use Apache2::RequestUtil;
use Devel::StackTrace;
use EBox::Exceptions::NotImplemented;
use SOAP::Lite;

# Group: Public methods

# Method: URI
#
#     Return the Unique Reference Identifier for the web service
#
# Returns:
#
#     String - the URI
#
sub URI
{
    throw EBox::Exceptions::NotImplemented();
}

# Group: Protected methods

# Method: _gatherParams
#
#     Get parameters from an array
#
#     This method is useful to run unit test for web service server
#     classes
#
# Parameters:
#
#     paramNames - Array ref containing the parameter names to parse
#
#     params - Array the parameter array source for parsing
#
# Returns:
#
#     Array ref - the values for the given parameter names
#
sub _gatherParams
{
    my ($self, $paramNames, @params) = @_;
    my @realParams;
    if ( @params > 0 and UNIVERSAL::isa($params[-1], 'SOAP::SOM')) {
        @realParams = SOAP::Server::Parameters::byNameOrOrder($paramNames, @params);
    } else {
        if ( @params % 2 == 0 ) {
            my %realParams = @params;
            @realParams = map { $realParams{$_} } @{$paramNames};
        } else {
            @realParams = @params;
        }
    }
    return \@realParams;
}

# Method: _cnFromRequest
#
#      Get the common name from the request since it is given by the
#      certificate used by SSL negotiation
#
# Returns:
#
#      Array ref - containing the user and the eBox's name as strings
#
sub _cnFromRequest
{
    my ($self) = @_;

    my $r = Apache2::RequestUtil->request();
    my $clientCN = $r->subprocess_env('SSL_CLIENT_S_DN_CN');
    my @retVal = split('_', $clientCN);
    return \@retVal;

}

# Method: _soapResult
#
#    Serialise SOAP result to be WSDL complaint
#
# Parameters:
#
#    retData - the returned data
#
sub _soapResult
{
    my ($class, $retData) = @_;

    my $trace = new Devel::StackTrace();
    if ($trace->frame(2)->package() eq 'SOAP::Server' ) {
        $SOAP::Constants::NS_SL_PERLTYPE = $class->URI();
        return SOAP::Data->name('return', $retData);
    } else {
        return $retData;
    }

}

1;
