# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::UsersSync::SOAPMaster;

use strict;
use warnings;

use EBox::Exceptions::MissingArgument;
use EBox::Config;
use EBox::Global;

use Devel::StackTrace;
use SOAP::Lite;

sub getCertificate
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');
    my $master = $users->master();

    my $cert = $master->getCertificate();
    return $self->_soapResult($cert);
}

sub registerSlave
{
    my ($self, $host, $port) = @_;

    my $users = EBox::Global->modInstance('users');
    my $master = $users->master();

    $master->addSlave($host, $port);

    return $self->_soapResult(0);
}


# Method: URI
#
# Overrides:
#
#      <EBox::RemoteServices::Server::Base>
#
sub URI {
    return 'urn:Users/Master';
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
