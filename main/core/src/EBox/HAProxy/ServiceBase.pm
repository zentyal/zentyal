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
#   This method must be always overrided by services implementing this interface.
#
# Returns:
#
#   integer - Port on <EBox::HAProxy::ServiceBase::targetHAProxyIP> where the service is listening.
#
sub targetHAProxyPort
{
    throw EBox::Exceptions::NotImplemented(
        'All EBox::HAProxy::ServiceBase implementations MUST specify the target port');
}

1;
