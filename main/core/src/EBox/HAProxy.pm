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
use EBox::Config;
use EBox::Gettext;
use EBox::Module::Base;
use EBox::Sudo;
use Error qw(:try);

use constant HAPROXY_DEFAULT_FILE => '/etc/default/haproxy';
use constant HAPROXY_CONF_FILE    => '/var/lib/zentyal/conf/haproxy.cfg';

# Constructor: _create
#
#   Create a new EBox::HAProxy module object
#
# Overrides:
#
#       <EBox::Module::Service::_create>
#
# Returns:
#
#       <EBox::HAProxy> - the recently created model
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
# Overrides:
#
#       <EBox::Module::Service::_usedFiles>
#
#sub _usedFiles
#{
#    return [
#        {
#            'file'   => HAPROXY_DEFAULT_FILE,
#            'module' => 'haproxy',
#            'reason' => __('To set the haproxy boot configuration'),
#        }
#    ]
#}

# Method: actions
#
# Overrides:
#
#       <EBox::Module::Service::actions>
#
#sub actions
#{
#    return [
#        {
#            'action' => __('Enable HAProxy daemon'),
#            'module' => 'haproxy',
#            'reason' => __('To start the HAProxy daemon.')
#        },
#    ];
#}

# Method: _daemons
#
#   Defines the set of daemons provided by HAProxy.
#
# Overrides:
#
#       <EBox::Module::Service::_daemons>
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
# Overrides:
#
#       <EBox::Module::Service::_daemonsToDisable>
#
sub _daemonsToDisable
{
    my ($self) = @_;

    return $self->_daemons();
}

# Method: _setConf
#
#   Write the haproxy configuration.
#
# Overrides:
#
#       <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    my @params = ();
    push (@params, haproxyconfpath => HAPROXY_CONF_FILE);
    $self->writeConfFile(HAPROXY_DEFAULT_FILE, 'core/haproxy-default.mas', \@params);

    my $webadminMod = $self->global()->modInstance('webadmin');
    # Prepare webadmin SSL certificates.
    $webadminMod->_writeCAFiles();

    @params = ();
    push (@params, zentyalconfdir => EBox::Config::conf());
    if (@{$webadminMod->_CAs(1)}) {
        push (@params, caFile => $webadminMod->CA_CERT_FILE());
    } else {
        push (@params, caFile => undef);
    }

    my $permissions = {
        uid => EBox::Config::user(),
        gid => EBox::Config::group(),
        mode => '0644',
        force => 1,
    };

    EBox::Module::Base::writeConfFileNoCheck(HAPROXY_CONF_FILE, 'core/haproxy.cfg.mas', \@params, $permissions);

}

# Method: isEnabled
#
# Overrides:
#
#       <EBox::Module::Service::isEnabled>
#
sub isEnabled
{
    # haproxy always has to be enabled
    return 1;
}

# Method: showModuleStatus
#
#   Indicate to ServiceManager if the module must be shown in Module
#   status configuration.
#
# Overrides:
#
#       <EBox::Module::Service::showModuleStatus>
#
sub showModuleStatus
{
    # we don't want it to appear in module status
    return undef;
}

# Method: addModuleStatus
#
#   Do not show entry in the module status widget
#
# Overrides:
#
#       <EBox::Module::Service::addModuleStatus>
#
sub addModuleStatus
{
}

# Method: _enforceServiceState
#
#   This method will restart always haproxy.
#
sub _enforceServiceState
{
    my ($self) = @_;

    my $script = $self->INITDPATH() . 'haproxy restart';
    EBox::Sudo::root($script);
}

1;
