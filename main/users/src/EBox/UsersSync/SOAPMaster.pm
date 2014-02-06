# Copyright (C) 2012-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::UsersSync::SOAPMaster;

use EBox::Exceptions::MissingArgument;
use EBox::Config;
use EBox::Global;

use Devel::StackTrace;
use SOAP::Lite;

sub getDN
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');
    my $dn = $users->ldap->dn();

    return $self->_soapResult($dn);
}

sub getRealm
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');
    my $realm = $users->kerberosRealm();

    return $self->_soapResult($realm);
}

sub getCertificate
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');
    my $master = $users->masterConf();

    my $cert = $master->getCertificate();
    return $self->_soapResult($cert);
}

sub registerSlave
{
    my ($self, $port, $cert) = @_;

    # my $req = Apache2::RequestUtil->request();
    # my $host = $req->headers_in()->{'X-Real-IP'};
    # FIXME: PENDIENTE DE MIGRAR A PSGI
    my $host = '127.0.0.1';

    my $users = EBox::Global->modInstance('users');
    my $master = $users->masterConf();

    $master->addSlave($host, $port, $cert);

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
