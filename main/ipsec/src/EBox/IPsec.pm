# Copyright (C) 2011 eBox Technologies S.L.
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
            EBox::Model::ModelProvider
            EBox::Model::CompositeProvider
            EBox::NetworkObserver
            EBox::FirewallObserver);

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;

use EBox::IPsec::FirewallHelper;
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
                                      printableName => 'IPsec');

    bless($self, $class);
    return $self;
}

# Method: modelClasses
#
# Overrides:
#
#       <EBox::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [
        'EBox::IPsec::Model::Connections',
        'EBox::IPsec::Model::ConfGeneral',
        'EBox::IPsec::Model::ConfPhase1',
        'EBox::IPsec::Model::ConfPhase2',
    ];
}

# Method: compositeClasses
#
# Overrides:
#
#    <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{
    return [
        'EBox::IPsec::Composite::Conf',
        'EBox::IPsec::Composite::Auth',
    ];
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
# FIXME
#    my @activeServers = @{$self->model('VPN')->getServers()};
    my @networksNoToMasquerade = ();
#    foreach my $server (@activeServers) {
#         EBox::debug(Dumper $server);
#         push(@networksNoToMasquerade, $server->{'right_subnet'});
#    }

    my $firewallHelper = new EBox::IPsec::FirewallHelper(
        service => $enabled,
        networksNoToMasquerade => \@networksNoToMasquerade,
    );

    return $firewallHelper;
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
                                        'separator' => 'UTM',
                                        'order' => 330
                                       );

    $folder->add(
                 new EBox::Menu::Item(
                                      'url' => 'VPN/IPsec',
                                      'text' => __('IPsec Connections'),
                                      'order' => 30
                                     )
    );

    $root->add($folder);
}

1;
