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

# Class: EBox::HA
#
#    HA module is responsible to have Zentyal server in a cluster.
#
#    It manages the cluster membership configuration (corosync) and
#    cluster resource managing (pacemaker)
#

package EBox::HA;

use base qw(EBox::Module::Service);

use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;

# Constants
use constant COROSYNC_CONF_FILE => '/etc/corosync/corosync.conf';

# Constructor: _create
#
# Overrides:
#
#       <Ebox::Module::Base::_create>
#
sub _create
{
    my $class = shift;

    my $self = $class->SUPER::_create(
        name => 'ha',
        printableName => __('High Availability'),
        @_
    );

    bless ($self, $class);

    return $self;
}

# Group: Public methods

# Method: menu
#
#       Set HA conf under System menu entry
#
# Overrides:
#
#       <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;

    my $system = new EBox::Menu::Folder(
            'name' => 'SysInfo',
            'text' => __('System'),
            'order' => 30
           );

    $system->add(new EBox::Menu::Item(
        url => 'HA/View/Cluster',
        text => $self->printableName(),
        separator => 'Core',
        order => 50,
    ));

    $root->add($system);
}

# Group: Protected methods

# Method: _daemons
#
# Overrides:
#
#       <EBox::Module::Service::_daemons>
#
sub _daemons
{
    my $daemons = [
       {
           name => 'corosync',
           type => 'init.d',
           pidfiles => ['/run/corosync.pid']
       },
    ];

    return $daemons;
}

# Method: _setConf
#
# Overrides:
#
#       <EBox::Module::Base::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    my $clusterSettings = $self->model('Cluster');

    my $iface = $clusterSettings->interfaceValue();
    my $network = EBox::Global->getInstance()->modInstance('network');
    # TODO: Launch exception when network addr is undef
    my $ifaces = [ { iface => $iface, netAddr => $network->ifaceNetwork($iface) }];
    my $localNodeAddr = $network->ifaceAddress($iface);
    if (ref($localNodeAddr) eq 'ARRAY') {
        $localNodeAddr = $localNodeAddr->[0];  # Take the first option
    }
    my $nodes = [ { addr => $localNodeAddr, name => 'local' }];
    my @params = (
        interfaces => $ifaces,
        nodes      => $nodes,
    );

    $self->writeConfFile(
        COROSYNC_CONF_FILE,
        "ha/corosync.conf.mas",
        \@params,
        { uid => '0', gid => '0', mode => '644' }
    );
}

1;
