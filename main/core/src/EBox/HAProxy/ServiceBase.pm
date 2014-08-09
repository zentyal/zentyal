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

# Method: isHTTPPortEnabled
#
#   Whether this service is enabled in haproxy for non SSL traffic.
#
# Returns:
#
#   boolean - True if is enabled for non SSL traffice or False.
#
sub isHTTPPortEnabled
{
    my ($self) = @_;

    # FIXME: implement this properly?
    return 1;
}

# Method: listeningHTTPPort
#
#   Provides the HTTP port assigned to this service on the ha proxy
#
# Returns:
#
#   integer - The HTTP port used by this service or undef if not active.
#
sub listeningHTTPPort
{
    my ($self) = @_;

    # FIXME: implement this properly?
    return 80;
}

# Method: isHTTPSPortEnabled
#
#   Whether this service is enabled in haproxy for SSL traffic.
#
# Returns:
#
#   boolean - True if is enabled for SSL traffice or False.
#
sub isHTTPSPortEnabled
{
    my ($self) = @_;

    # FIXME: implement this properly?
    return 1;
}

# Method: listeningHTTPSPort
#
#   Provides the HTTPS port assigned to this service on the ha proxy
#
# Returns:
#
#   integer - The HTTPS port used by this service.
#
sub listeningHTTPSPort
{
    my ($self) = @_;

    # FIXME: implement this properly?
    return 443;
}

# Method: allowServiceDisabling
#
#   Most services should be disableable from the reverse proxy, except for instance, webadmin which is a core service.
#
# Returns:
#
#   boolean - Whether this service may be disabled from the reverse proxy.
#
sub allowServiceDisabling
{
    return 1;
}

# Method: serviceId
#
# Returns:
#
#   string - A unique ID across Zentyal that identifies this HAProxy service.
#
sub serviceId
{
    my ($self) = @_;

    return $self->name() . 'HAProxyId';
}

# Method: defaultHTTPSPort
#
# Returns:
#
#   integer - The default public port that should be used to publish this service over SSL or undef if unused.
#
sub defaultHTTPSPort
{
    return undef;
}

# Method: blockHTTPSPortChange
#
# Returns:
#
#   boolean - Whether the SSL port may be customised or not.
#
sub blockHTTPSPortChange
{
    return undef;
}

# Method: defaultHTTPPort
#
# Returns:
#
#   integer - The default public port that should be used to publish this service or undef if unused.
#
sub defaultHTTPPort
{
    return undef;
}

# Method: blockHTTPPortChange
#
# Returns:
#
#   boolean - Whether the port may be customised or not.
#
sub blockHTTPPortChange
{
    return undef;
}

# Method: pathHTTPSSSLCertificate
#
# Returns:
#
#   array of strings - The full paths to the SSL certificates files to use by
#   HAProxy or empty list.
#
sub pathHTTPSSSLCertificate
{
    return [];
}

# Method: caServiceIdForHTTPS
#
# Returns:
#
#   string - The CA SSL service name for HAProxy.
#
sub caServiceIdForHTTPS
{
    my ($self) = @_;

    return 'zentyal_' . $self->name();
}

# Method: targetVHostDomains
#
# Returns:
#
#   list - List of domains that the target service will handle. If empty, this service will be used as the default
#          traffic destination for the configured ports.
#
sub targetVHostDomains
{
    return [];
}

# Method: targetIP
#
#   This method must be always overrided by services implementing this interface.
#
# Returns:
#
#   string - IP address where the service is listening, usually 127.0.0.1 .
#
sub targetIP
{
    throw EBox::Exceptions::NotImplemented(
        'All EBox::HAProxy::ServiceBase implementations MUST specify the target IP');
}

# Method: targetHTTPPort
#
#   This method must be always overrided by services implementing this interface if defaultHTTPPort is not undef
#   or blockHTTPPortChange is False.
#
# Returns:
#
#   integer - Port on <EBox::HAProxy::ServiceBase::targetIP> where the service is listening.
#
sub targetHTTPPort
{
    my ($self) = @_;

    if ($self->defaultHTTPPort() or (not $self->blockHTTPPortChange())) {
        throw EBox::Exceptions::NotImplemented(
            'All EBox::HAProxy::ServiceBase implementations MUST specify the target port');
    }
}

# Method: targetHTTPSPort
#
#   This method must be always overrided by services implementing this interface if defaultHTTPSPort is not
#   undef or blockHTTPSPortChange is False.
#
#   This port should not be using SSL itself, HAProxy will decode all SSL traffic before redirecting it there.
#
# Returns:
#
#   integer - Port on <EBox::HAProxy::ServiceBase::targetIP> where the service is listening for SSL requests.
#
sub targetHTTPSPort
{
    my ($self) = @_;

    if ($self->defaultHTTPSPort() or (not $self->blockHTTPSPortChange())) {
        throw EBox::Exceptions::NotImplemented(
            'All EBox::HAProxy::ServiceBase implementations MUST specify the target port');
    }
}

# only override if it is a internal service not modifiable by the user
sub HAProxyInternalService
{
    return undef;
}

# MNethod: HAProxyPreSetConf
#
# this method we will invoked before HAProxy set conf, it could be useful
# to do things like putting certificates in place
#
# Default implementation is to do nothing
sub HAProxyPreSetConf
{
}

1;
