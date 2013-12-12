# Copyright (C) 2011-2012 Zentyal S.L.
#
# This program is free softwa re; you can redistribute it and/or modify
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

package EBox::IPsec;

use base qw(EBox::Module::Service
            EBox::NetworkObserver
            EBox::FirewallObserver
            EBox::LogObserver);

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;

use EBox::IPsec::FirewallHelper;
use EBox::IPsec::LogHelper;
use EBox::NetWrappers qw();

use constant IPSECCONFFILE => '/etc/ipsec.conf';
use constant IPSECSECRETSFILE => '/etc/ipsec.secrets';

# Constructor: _create
#
#      Create a new EBox::IPsec module object
#
# Returns:
#
#      <EBox::IPsec> - the recently created model
#
sub _create
{
    my $class = shift;

    my $self = $class->SUPER::_create(name => 'ipsec',
                                      printableName => 'IPsec',
                                      @_);

    bless($self, $class);

    return $self;
}

# Method: usedFiles
#
#       Override EBox::Module::Service::usedFiles
#
sub usedFiles
{
    return [
            {
              'file' => IPSECCONFFILE,
              'module' => 'ipsec',
              'reason' => __('To configure OpenSwan IPsec.')
            },
            {
              'file' => IPSECSECRETSFILE,
              'module' => 'ipsec',
              'reason' => __('To configure OpenSwan IPsec passwords.')
            },
    ];
}

# Method: _daemons
#
# Overrides:
#
#      <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        {
            'name' => 'ipsec',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/pluto/pluto.pid'],
        }
    ];
}

# Method: initialSetup
#
# Overrides:
#
#      <EBox::Module::Base::initialSetup>
#
sub initialSetup
{
    my ($self, $version) = @_;

    unless ($version) {
        my $services = EBox::Global->modInstance('services');

        my $serviceName = 'IPsec';
        unless($services->serviceExists(name => $serviceName)) {
            $services->addMultipleService(
                'name' => $serviceName,
                'description' => __('IPsec VPN'),
                'internal' => 1,
                'readOnly' => 1,
                'services' => $self->_services(),
            );
        }

        my $firewall = EBox::Global->modInstance('firewall');
        $firewall->setExternalService($serviceName, 'accept');

        $firewall->saveConfigRecursive();
    }
}

sub _services
{
    return [
             {
                 'protocol' => 'esp',
                 'sourcePort' => 'any',
                 'destinationPort' => 'any',
             },
             {
                 'protocol' => 'udp',
                 'sourcePort' => 'any',
                 'destinationPort' => '500',
             },
             {
                 'protocol' => 'udp',
                 'sourcePort' => 'any',
                 'destinationPort' => '4500',
             },
    ];
}

# Method: _setConf
#
# Overrides:
#
#      <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    $self->_setIPsecConf();
    $self->_setIPsecSecrets();
}

sub _setIPsecConf
{
    my ($self) = @_;

    my @params = ();

    push (@params, tunnels => $self->tunnels());

    $self->writeConfFile(IPSECCONFFILE, "ipsec/ipsec.conf.mas", \@params,
                            { 'uid' => 'root', 'gid' => 'root', mode => '600' });
}

sub _setIPsecSecrets
{
    my ($self) = @_;

    my @params = ();

    push (@params, tunnels => $self->tunnels());

    $self->writeConfFile(IPSECSECRETSFILE, "ipsec/ipsec.secrets.mas", \@params,
                            { 'uid' => 'root', 'gid' => 'root', mode => '600' });
}

sub tunnels
{
    my ($self) = @_;

    my $vpn = $self->model('Connections');

    return $vpn->tunnels();
}

sub firewallHelper
{
    my ($self) = @_;

    my $enabled = $self->isEnabled();

    my @activeTunnels = @{$self->tunnels()};
    my @networksNoToMasquerade = ();
    foreach my $tunnel (@activeTunnels) {
        my $subnet = $tunnel->{'right_subnet'};
        next unless $subnet;
        push(@networksNoToMasquerade, $subnet);
    }

    my $firewallHelper = new EBox::IPsec::FirewallHelper(
        service => $enabled,
        networksNoToMasquerade => \@networksNoToMasquerade,
    );

    return $firewallHelper;
}

# Method: logHelper
#
# Overrides:
#
#       <EBox::LogObserver::logHelper>
#
sub logHelper
{
    my ($self, @params) = @_;
    return EBox::IPsec::LogHelper->new($self, @params);
}

# Method: tableInfo
#
# Overrides:
#
#       <EBox::LogObserver::tableInfo>
#
sub tableInfo
{
    my ($self) = @_;
    my $titles = {
                  timestamp => __('Date'),
                  event     => __('Event'),
                  tunnel    => __('Connection name'),
                 };
    my @order = qw(timestamp event tunnel);

    my $events = {
                  initialized   => __('Initialization sequence completed'),
                  stopped       => __('Stopping completed'),

                  connectionInitiated   => __('Connection initiated'),
                  connectionReset       => __('Connection terminated'),
                 };

    return [{
            'name'      => $self->printableName(),
            'tablename' => 'ipsec',
            'titles'    => $titles,
            'order'     => \@order,
            'timecol'   => 'timestamp',
            'filter'    => ['tunnel'],
            'events'    => $events,
            'eventcol'  => 'event'
           }];
}


# Method: menu
#
#       Overrides <EBox::Module::menu> method.
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder(
                                        'name' => 'VPN',
                                        'text' => 'VPN',
                                        'separator' => 'Infrastructure',
                                        'order' => 330
                                       );

    $folder->add(
                 new EBox::Menu::Item(
                                      'url' => 'VPN/IPsec',
                                      'text' => __('IPsec'),
                                      'order' => 30
                                     )
    );

    $root->add($folder);
}

1;
