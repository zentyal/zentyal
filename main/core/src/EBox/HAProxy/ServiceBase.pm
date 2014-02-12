# Copyright (C) 2014 Zentyal S.L.
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

# Class:
#
#   <EBox::HAProxy::ServiceBase>
#
#   Base class to be implemented by all Zentyal services (<EBox::Module::Service>) that want to be published using
#   the reverse proxy provided by HAProxy.
#
package EBox::HAProxy::ServiceBase;

use EBox::Exceptions::NotImplemented;
use EBox::Gettext;
use EBox::Global;

# Constructor: new
#
#   Create a new <EBox::HAProxy::ServiceBase> object.
#
# Returns:
#
#   <EBox::HAProxy::ServiceBase> - the recently created object.
#
sub new
{
    my $class = shift;
    my $self = {};
    bless ($self, $class);
    return $self;
}

# Method: isPortEnabledInHAProxy
#
#   Whether this service is enabled in haproxy for non SSL traffic.
#
# Returns:
#
#   boolean - True if is enabled for non SSL traffice or False.
#
sub isPortEnabledInHAProxy
{
    my ($self) = @_;

    my $global = $self->global();
    my $haproxyMod = $global->modInstance('haproxy');
    my $services = $haproxyMod->model('HAProxyServices');
    my $moduleRow = $services->find(serviceId => $self->HAProxyServiceId());

    my $portItem = $moduleRow->elementByName('port');
    return ($portItem->selectedType() eq 'port_number');
}

# Method: usedHAProxyPort
#
#   Provides the HTTP port assigned to this service on the ha proxy
#
# Returns:
#
#   integer - The HTTP port used by this service or undef if not active.
#
sub usedHAProxyPort
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance(1);
    my $haproxyMod = $global->modInstance('haproxy');
    my $services = $haproxyMod->model('HAProxyServices');
    my $moduleRow = $services->find(serviceId => $self->HAProxyServiceId());

    if ($self->isPortEnabledInHAProxy()) {
        return $moduleRow->valueByName('port');
    } else {
        return undef;
    }
}

# Method: isSSLPortEnabledInHAProxy
#
#   Whether this service is enabled in haproxy for SSL traffic.
#
# Returns:
#
#   boolean - True if is enabled for SSL traffice or False.
#
sub isSSLPortEnabledInHAProxy
{
    my ($self) = @_;

    my $global = $self->global();
    my $haproxyMod = $global->modInstance('haproxy');
    my $services = $haproxyMod->model('HAProxyServices');
    my $moduleRow = $services->find(serviceId => $self->HAProxyServiceId());

    unless ($moduleRow) {
        return undef;
    }

    my $sslPortItem = $moduleRow->elementByName('sslPort');
    return ($sslPortItem->selectedType() eq 'sslPort_number');
}

# Method: usedHAProxySSLPort
#
#   Provides the HTTPS port assigned to this service on the ha proxy
#
# Returns:
#
#   integer - The HTTPS port used by this service.
#
sub usedHAProxySSLPort
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance(1);
    my $haproxyMod = $global->modInstance('haproxy');
    my $services = $haproxyMod->model('HAProxyServices');
    my $moduleRow = $services->find(serviceId => $self->HAProxyServiceId());

    if ($self->isSSLPortEnabledInHAProxy()) {
        return $moduleRow->valueByName('sslPort');
    } else {
        return undef;
    }
}

# Method: allowDisableHAProxyService
#
#   Most services should be disableable from the reverse proxy, except for instance, webadmin which is a core service.
#
# Returns:
#
#   boolean - Whether this service may be disabled from the reverse proxy.
#
sub allowDisableHAProxyService
{
    return 1;
}

# Method: HAProxyServiceId
#
#   This method must be always overrided by services implementing this interface.
#
# Returns:
#
#   string - A unique ID across Zentyal that identifies this HAProxy service.
#
sub HAProxyServiceId
{
    throw EBox::Exceptions::NotImplemented(
        'All EBox::HAProxy::ServiceBase implementations MUST specify a unique ServiceId');
}

# Method: defaultHAProxySSLPort
#
# Returns:
#
#   integer - The default public port that should be used to publish this service over SSL or undef if unused.
#
sub defaultHAProxySSLPort
{
    return undef;
}

# Method: blockHAProxySSLPort
#
# Returns:
#
#   boolean - Whether the SSL port may be customised or not.
#
sub blockHAProxySSLPort
{
    return undef;
}

# Method: defaultHAProxyPort
#
# Returns:
#
#   integer - The default public port that should be used to publish this service or undef if unused.
#
sub defaultHAProxyPort
{
    return undef;
}

# Method: blockHAProxyPort
#
# Returns:
#
#   boolean - Whether the port may be customised or not.
#
sub blockHAProxyPort
{
    return undef;
}

# Method: pathHAProxySSLCertificate
#
# Returns:
#
#   string - The full path to the SSL certificate file to use by HAProxy or undef.
#
sub pathHAProxySSLCertificate
{
    return undef;
}

# Method: caServiceForHAProxy
#
# Returns:
#
#   string - The CA SSL service name for HAProxy.
#
sub caServiceIdForHAProxy

{
    my ($self) = @_;

    return 'zentyal_' . $self->name();
}

# Method: targetHAProxyDomains
#
# Returns:
#
#   list - List of domains that the target service will handle. If empty, this service will be used as the default
#          traffic destination for the configured ports.
#
sub targetHAProxyDomains
{
    return [];
}

# Method: targetHAProxyIP
#
#   This method must be always overrided by services implementing this interface.
#
# Returns:
#
#   string - IP address where the service is listening, usually 127.0.0.1 .
#
sub targetHAProxyIP
{
    throw EBox::Exceptions::NotImplemented(
        'All EBox::HAProxy::ServiceBase implementations MUST specify the target IP');
}

# Method: targetHAProxyPort
#
#   This method must be always overrided by services implementing this interface if defaultHAProxyPort is not undef
#   or blockHAProxyPort is False.
#
# Returns:
#
#   integer - Port on <EBox::HAProxy::ServiceBase::targetHAProxyIP> where the service is listening.
#
sub targetHAProxyPort
{
    my ($self) = @_;

    if ($self->defaultHAProxyPort() or (not $self->blockHAProxyPort())) {
        throw EBox::Exceptions::NotImplemented(
            'All EBox::HAProxy::ServiceBase implementations MUST specify the target port');
    }
}

# Method: targetHAProxySSLPort
#
#   This method must be always overrided by services implementing this interface if defaultHAProxySSLPort is not
#   undef or blockHAProxySSLPort is False.
#
#   This port should not be using SSL itself, HAProxy will decode all SSL traffic before redirecting it there.
#
# Returns:
#
#   integer - Port on <EBox::HAProxy::ServiceBase::targetHAProxyIP> where the service is listening for SSL requests.
#
sub targetHAProxySSLPort
{
    my ($self) = @_;

    if ($self->defaultHAProxySSLPort() or (not $self->blockHAProxySSLPort())) {
        throw EBox::Exceptions::NotImplemented(
            'All EBox::HAProxy::ServiceBase implementations MUST specify the target port');
    }
}

# only override if it is a internal service not modifiable by the user
sub HAProxyInternalService
{
    return undef;
}

1;
