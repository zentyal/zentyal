# Copyright (C) 2011-2014 Zentyal S.L.
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
use strict;
use warnings;

package EBox::L2TP;

use base qw(EBox::Module::LDAP
            EBox::NetworkObserver
            EBox::FirewallObserver
            EBox::LogObserver);

use EBox::Gettext;

use EBox::L2TP::FirewallHelper;
use EBox::L2TP::LogHelper;
use EBox::L2TP::LDAPUser;
use EBox::NetWrappers;
use File::Slurp;

use constant IPSECCONFFILE => '/etc/ipsec.conf';
use constant IPSECSECRETSFILE => '/etc/ipsec.secrets';

# Constructor: _create
#
#      Create a new EBox::L2TP module object
#
# Returns:
#
#      <EBox::L2TP> - the recently created model
#
sub _create
{
    my $class = shift;

    my $self = $class->SUPER::_create(name => 'l2tp',
                                      printableName => 'L2TP',
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
    my @conf_files = ();

    push (@conf_files, {
        'file' => IPSECCONFFILE,
        'module' => 'ipsec',
        'reason' => __('To configure OpenSwan IPsec.')
    });

    push (@conf_files, {
        'file' => IPSECSECRETSFILE,
        'module' => 'ipsec',
        'reason' => __('To configure OpenSwan IPsec passwords.')
    });

    return \@conf_files;
}

# overriden to stop deleted daemons
sub _manageService
{
    my ($self, @params) = @_;
    my $state = $self->get_state();
    if ($state->{deleted_daemons}) {
        my @deleted = @{ delete $state->{deleted_daemons} };
        foreach my $daemon (@deleted) {
            try {
                EBox::Sudo::root("/sbin/stop '$daemon'")
            } catch {
                # we assume that it was already stopped
            }
        }
        $self->set_state($state);
    }

    return $self->SUPER::_manageService(@params);
}

# Method: addDeletedDaemon
#
# add daemon maes to the delete list so in next restart we can
# do cleanup properly of their init files
sub addDeletedDaemon
{
    my ($self, @daemons) = @_;
    my $state = $self->get_state();
    if (not $state->{deleted_daemons}) {
        $state->{deleted_daemons} = [];
    }

    push @{ $state->{deleted_daemons} }, @daemons;
    $self->set_state($state);
}

# overriden to put old l2tp daemons in deleted daemons list
sub aroundRestoreConfig
{
    my ($self, @options) = @_;
    my @deleted = map {
        $_->{name}
    } @{ $self->model('Connections')->l2tpDaemons() };
    $self->SUPER::restoreConfig(@options);
}

# Method: _daemons
#
# Overrides:
#
#      <EBox::Module::Service::_daemons>
#
sub _daemons
{
    my ($self) = @_;

    my @daemons = ();
    push @daemons, {
        'name' => 'ipsec',
        'type' => 'init.d',
        'pidfiles' => ['/var/run/pluto/pluto.pid'],
    };
    push @daemons, @{ $self->model('Connections')->l2tpDaemons()};

    return \@daemons;
}

# Method: _daemonsToDisable
#
# Overrides:
#
#   <EBox::Module::Service::_daemonsToDisable>
#
sub _daemonsToDisable
{
    return [ { 'name' => 'xl2tpd', 'type' => 'init.d' } ];
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
    my $global = $self->global();

    unless ($version) {
        my $services = $global->modInstance('services');

        my $serviceName = 'L2TP';
        unless($services->serviceExists(name => $serviceName)) {
            $services->addMultipleService(
                'name' => $serviceName,
                'description' => __('L2TP based VPN'),
                'internal' => 1,
                'readOnly' => 1,
                'services' => $self->_services(),
            );
        }

        my $firewall = $global->modInstance('firewall');
        $firewall->setExternalService($serviceName, 'accept');

        $firewall->saveConfigRecursive();
    }
}

sub _services
{
    my @services = ();

    # Encapsulation header.
    push (@services, {
        'protocol' => 'esp',
        'sourcePort' => 'any',
        'destinationPort' => 'any',
        });

    # Internet Key Exchange
    push (@services, {
        'protocol' => 'udp',
        'sourcePort' => 'any',
        'destinationPort' => '500',
        });

    # NAT traversal
    push (@services, {
        'protocol' => 'udp',
        'sourcePort' => 'any',
        'destinationPort' => '4500',
        });

    return \@services;
}

sub _ldapModImplementation
{
    my ($self) = @_;
    return EBox::L2TP::LDAPUser->new();
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
    $self->_setXL2TPDConf();
    $self->_setKernelParameters();
}

sub _setIPsecConf
{
    my ($self) = @_;

    my @params = ();

    push (@params, tunnels => $self->tunnels());

    $self->writeConfFile(IPSECCONFFILE, "l2tp/ipsec.conf.mas", \@params,
                            { 'uid' => 'root', 'gid' => 'root', mode => '600' });
}

sub _setIPsecSecrets
{
    my ($self) = @_;

    my @params = ();

    push (@params, tunnels => $self->tunnels());

    $self->writeConfFile(IPSECSECRETSFILE, "l2tp/ipsec.secrets.mas", \@params,
                            { 'uid' => 'root', 'gid' => 'root', mode => '600' });
}

sub _setXL2TPDConf
{
    my ($self) = @_;
    my $global = $self->global();

    # Clean all upstart and configuration files, the current ones will be regenerated
    EBox::Sudo::silentRoot(
        "rm -rf /etc/init/zentyal-xl2tpd.*.conf",
        "rm -rf /etc/ppp/zentyal-xl2tpd.*",
        "rm -rf /etc/xl2tpd/zentyal-xl2tpd.*.conf"
    );

    my $users = $global->modInstance('samba');
    my $workgroup = $users->workgroup();

    my $permissions = {
        uid => 'root',
        gid => 'root',
        mode => '644',
    };

    foreach my $tunnel (@{ $self->model('Connections')->l2tpDaemons() }) {
        my @params = ();

        my $validationGroup = $tunnel->{group};
        push (@params, group => "$workgroup\\\\$validationGroup");
        push (@params, tunnel => $tunnel);

        $self->writeConfFile(
            "/etc/xl2tpd/$tunnel->{name}.conf", "l2tp/xl2tpd.conf.mas", \@params, $permissions);
        $self->writeConfFile(
            "/etc/ppp/$tunnel->{name}.options", "l2tp/options.xl2tpd.mas", \@params, $permissions);
        $self->writeConfFile(
            "/etc/init/$tunnel->{name}.conf", "l2tp/upstart-xl2tpd.mas", \@params, $permissions);
    }
}

sub _setKernelParameters
{
    my @commands;
    push(@commands, '/sbin/sysctl -q -w net.ipv4.conf.default.accept_redirects="0"');
    push(@commands, '/sbin/sysctl -q -w net.ipv4.conf.default.send_redirects="0"');
    EBox::Sudo::root(@commands);
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
    my @L2TPInterfaces = ();
    foreach my $tunnel (@activeTunnels) {
        my @interfaces = EBox::NetWrappers::iface_by_address($tunnel->{local_ip});
        if (@interfaces) {
            push (@L2TPInterfaces, @interfaces);
        }
        my $subnet = $tunnel->{'right_subnet'};
        next unless $subnet;
        push(@networksNoToMasquerade, $subnet);
    }

    my $firewallHelper = new EBox::L2TP::FirewallHelper(
        service => $enabled,
        networksNoToMasquerade => \@networksNoToMasquerade,
        L2TPInterfaces => \@L2TPInterfaces,
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
    return EBox::L2TP::LogHelper->new($self, @params);
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
            'tablename' => 'l2tp',
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

    $root->add(new EBox::Menu::Item('url' => 'L2TP/View/Connections',
                                    'text' => $self->printableName(),
                                    'icon' => 'l2tp',
                                    'order' => 400));
}

1;
