# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::IPsec;

use base qw(EBox::Module::Service
            EBox::NetworkObserver
            EBox::FirewallObserver
            EBox::LogObserver);

use EBox::Gettext;

use EBox::IPsec::FirewallHelper;
use EBox::IPsec::LogHelper;
use EBox::NetWrappers qw();
use File::Slurp;
use TryCatch;

use constant IPSECCONFFILE => '/etc/ipsec.conf';
use constant IPSECSECRETSFILE => '/etc/ipsec.secrets';
use constant CHAPSECRETSFILE => '/etc/ppp/chap-secrets';

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
    my @conf_files = ();

    push (@conf_files, {
        'file' => IPSECCONFFILE,
        'module' => 'ipsec',
        'reason' => __('To configure Libreswan IPsec.')
    });

    push (@conf_files, {
        'file' => IPSECSECRETSFILE,
        'module' => 'ipsec',
        'reason' => __('To configure Libreswan IPsec passwords.')
    });

    push (@conf_files, {
        'file' => CHAPSECRETSFILE,
        'module' => 'ipsec',
        'reason' => __('To configure L2TP/IPSec users when not using Active Directory validation.')
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
                EBox::Sudo::root("systemctl stop '$daemon'")
            } catch {
                # we assume that it was already stopped
            }
        }
        $self->set_state($state);
    }

    return $self->SUPER::_manageService(@params);
}

# Method: depends
#
# Overriden to add samba to dependencies if it is installed and enabled
sub depends
{
    my ($self) = @_;
    my $depends = $self->SUPER::depends();

    my $samba = $self->global()->modInstance('samba');
    if ($samba and $samba->isEnabled()) {
        push @{ $depends }, 'samba';
    }

    return $depends
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

    my @daemons = ({ 'name' => 'ipsec' });
    push (@daemons, @{ $self->model('Connections')->l2tpDaemons()});
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
        my $services = $global->modInstance('network');

        my $serviceName = 'IPsec';
        unless($services->serviceExists(name => $serviceName)) {
            $services->addMultipleService(
                'name' => $serviceName,
                'description' => __('IPsec based VPN'),
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

sub _setXL2TPDUsers
{
    my ($self) = @_;

    my $model = $self->model('UsersFile');

    my $l2tpConf = '';
    foreach my $user (@{$model->getUsers()}) {
        $user->{ipaddr} = '*' unless $user->{ipaddr};
        $l2tpConf .= "$user->{user} l2tp $user->{passwd} $user->{ipaddr}\n";
    }
    my $file = read_file(CHAPSECRETSFILE);
    my $mark = '# L2TP_CONFIG - managed by Zentyal. Dont edit this section #';
    my $endMark = '# END of L2TP_CONFIG section #';
    if ($file =~ m/$mark/sm) {
        $file =~ s/$mark.*$endMark/$mark\n$l2tpConf$endMark/sm;
    } else {
        $file .= $mark . "\n" . $l2tpConf . $endMark . "\n";
    }

    write_file(CHAPSECRETSFILE, $file);
}

sub _setXL2TPDConf
{
    my ($self) = @_;
    my $global = $self->global();

    # Clean all systemd and configuration files, the current ones will be regenerated
    EBox::Sudo::silentRoot(
        "rm -rf /lib/systemd/system/zentyal-xl2tpd.*.conf",
        "rm -rf /etc/ppp/zentyal-xl2tpd.*",
        "rm -rf /etc/xl2tpd/zentyal-xl2tpd.*.conf"
    );

    my $workgroup = undef;
    my $users = $self->model('Users');
    my $validationGroup = $users->validationGroup();

    if ($validationGroup) {
        my $users = $global->modInstance('samba');
        $workgroup = $users->workgroup();
    } else {
        $self->_setXL2TPDUsers();
    }

    my $permissions = {
        uid => 'root',
        gid => 'root',
        mode => '644',
    };

    foreach my $tunnel (@{ $self->model('Connections')->l2tpDaemons() }) {
        my @params = ();

        if ($validationGroup) {
            push (@params, group => "$workgroup\\\\$validationGroup");
            push (@params, chap => 0);
        } else {
            push (@params, group => undef);
            push (@params, chap => 1);
        }
        push (@params, tunnel => $tunnel);

        $self->writeConfFile(
            "/etc/xl2tpd/$tunnel->{name}.conf", "ipsec/xl2tpd.conf.mas", \@params, $permissions);
        $self->writeConfFile(
            "/etc/ppp/$tunnel->{name}.options", "ipsec/options.xl2tpd.mas", \@params, $permissions);
        $self->writeConfFile(
            "/lib/systemd/system/$tunnel->{name}.service", "ipsec/systemd-xl2tpd.mas", \@params, $permissions);

    }
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
    my $hasL2TP = undef;
    my @L2TPInterfaces = ();
    foreach my $tunnel (@activeTunnels) {
        if ($tunnel->{type} eq 'l2tp') {
            $hasL2TP = 1;
            my @interfaces = `ip a | grep 'inet $tunnel->{local_ip} peer' | sed 's/.* //'`;
            chomp (@interfaces);
            if (@interfaces) {
                push (@L2TPInterfaces, @interfaces);
            }
        }
        my $subnet = $tunnel->{'right_subnet'};
        next unless $subnet;
        push(@networksNoToMasquerade, $subnet);
    }

    my $firewallHelper = new EBox::IPsec::FirewallHelper(
        service => $enabled,
        networksNoToMasquerade => \@networksNoToMasquerade,
        hasL2TP => $hasL2TP,
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
                                        'icon' => 'openvpn',
                                        'name' => 'VPN',
                                        'text' => 'VPN',
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
