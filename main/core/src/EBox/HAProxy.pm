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

package EBox::HAProxy;
use base qw(EBox::Module::Service);

use strict;
use warnings;

use EBox;
use EBox::Gettext;
use Error qw(:try);

use constant HAPROXY_DEFAULT_FILE => '/etc/default/haproxy';

# Constructor: _create
#
#   Create a new EBox::HAProxy module object
#
#   Override <EBox::Module::Service::_create>
#
# Returns:
#
#      <EBox::HAProxy> - the recently created model
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(
        name   => 'haproxy',
        printableName => __('Zentyal HAProxy'),
        @_
    );

    bless($self, $class);
    return $self;
}

# Method: usedFiles
#
#   Defines the set of system files that HAProxy will change.
#
#   Override <EBox::Module::Service::_usedFiles>
#
sub _usedFiles
{
    return [
        {
            'file'   => HAPROXY_DEFAULT_FILE,
            'module' => 'haproxy',
            'reason' => __('To set the haproxy boot configuration'),
        }
    ]
}

# Method: actions
#
#    Override <EBox::Module::Service::actions>
#
sub actions
{
    return [
        {
            'action' => __('Enable HAProxy daemon'),
            'module' => 'haproxy',
            'reason' => __('To start the HAProxy daemon.')
        },
    ];
}

# Method: _daemons
#
#   Defines the set of daemons provided by HAProxy.
#
#   Override <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        {
            'name' => 'haproxy',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/haproxy.pid'],
        }
    ]
}

# Method: _daemonsToDisable
#
#   Defines the set of daemons that should not be started on boot but handled by Zentyal.
#
#   Override <EBox::Module::Service::_daemonsToDisable>
#
#sub _daemonsToDisable
{
    my ($self) = @_;

    return $self->_daemons();
}

# Method: _setConf
#
#   Write the haproxy configuration.
#
#   Override <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    $params = [];
    $self->writeConfFile(HAPROXY_DEFAULT_FILE, 'core/haproxy-default.mas', $params);
}


1;
