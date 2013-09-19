# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::PPTP;

use base qw(EBox::Module::Service
            EBox::FirewallObserver
            EBox::LogObserver);

use EBox::Global;
use EBox::Gettext;

use EBox::Dashboard::Section;
use EBox::Dashboard::Value;

use EBox::PPTPLogHelper;

use Net::IP;
use Error qw(:try);
use File::Slurp;

use constant PPTPDCONFFILE => '/etc/pptpd.conf';
use constant OPTIONSCONFFILE => '/etc/ppp/pptpd-options';
use constant CHAPSECRETSFILE => '/etc/ppp/chap-secrets';

# Constructor: _create
#
#      Create a new EBox::PPTP module object
#
# Returns:
#
#      <EBox::PPTP> - the recently created model
#
sub _create
{
    my $class = shift;

    my $self = $class->SUPER::_create(name => 'pptp',
            printableName => 'PPTP',
            domain => 'zentyal-pptp',
            @_);

    bless($self, $class);
    return $self;
}

# Method: usedFiles
#
# Overrides:
#
#      <EBox::ServiceModule::ServiceInterface::usedFiles>
#
sub usedFiles
{
    my @usedFiles;

    push (@usedFiles, { 'file' => PPTPDCONFFILE,
                        'module' => 'pptp',
                        'reason' => __('To configure PPTP server.')
                      },
                      { 'file' => OPTIONSCONFFILE,
                        'module' => 'pptp',
                        'reason' => __('To configure PPTP options.')
                      },
                      { 'file' => CHAPSECRETSFILE,
                        'module' => 'pptp',
                        'reason' => __('To configure PPTP users.')
                      },
         );

    return \@usedFiles;
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
            'name' => 'pptpd',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/pptpd.pid'],
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

        my $serviceName = 'PPTP';
        unless($services->serviceExists(name => $serviceName)) {
            $services->addMultipleService(
                'name' => $serviceName,
                'description' => __('PPTP VPN'),
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
                 'protocol' => 'gre',
                 'sourcePort' => 'any',
                 'destinationPort' => 'any',
             },
             {
                 'protocol' => 'tcp',
                 'sourcePort' => 'any',
                 'destinationPort' => '1723',
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

    my @params;

    my $config = $self->model('Config')->row();
    my $network = $config->printableValueByName('network');
    if ($network) {
        my $ip = new Net::IP($network);
        $ip++;
        push (@params, localip => $ip->ip());
        $ip++;
        my $last = new Net::IP($ip->last_ip());
        my ($last1, $last2, $last3, $last4) = split(/\./, $last->ip());
        $last4--;
        my $remoteip = $ip->ip().'-'.$last4;
        push (@params, remoteip => $remoteip);

        $self->writeConfFile(PPTPDCONFFILE, "pptp/pptpd.conf.mas",
                             \@params, { 'uid' => 'root',
                                         'gid' => 'root',
                                         mode => '640' });
    }

    @params = ();
    push (@params, nameserver1 => $config->valueByName('nameserver1'));
    push (@params, nameserver2 => $config->valueByName('nameserver2'));
    push (@params, wins1 => $config->valueByName('wins1'));
    push (@params, wins2 => $config->valueByName('wins2'));

    $self->writeConfFile(OPTIONSCONFFILE, "pptp/pptpd-options.mas",
                         \@params, { 'uid' => 'root',
                                     'gid' => 'root',
                                     mode => '640' });

    $self->_setUsers();
}

sub _setUsers
{
    my ($self) = @_;

    my $model = $self->model('Users');

    my $pptpConf = '';
    foreach my $user (@{$model->getUsers()}) {
        $user->{ipaddr} = '*' unless $user->{ipaddr};
        $pptpConf .= "$user->{user} pptpd $user->{passwd} $user->{ipaddr}\n";
    }
    my $file = read_file(CHAPSECRETSFILE);
    my $oldMark = '# PPTP_CONFIG #';
    my $mark = '# PPTP_CONFIG - managed by Zentyal. Dont edit this section #';
    my $endMark = '# END of PPTP_CONFIG section #';
    if ($file =~ m/$mark/sm) {
        $file =~ s/$mark.*$endMark/$mark\n$pptpConf$endMark/sm;
    } elsif ($file =~ m/$oldMark/) {
        # convert to new format
        $file =~ s/$oldMark.*$oldMark/$mark\n$pptpConf$endMark/sm;
    } else {
        $file .= $mark . "\n" . $pptpConf . $endMark . "\n";
    }

    write_file(CHAPSECRETSFILE, $file);
}

# Method: menu
#
# Overrides:
#
#      <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder(
                                        'icon' => 'openvpn',
                                        'name' => 'VPN',
                                        'text' => 'VPN',
                                        'separator' => 'Infrastructure',
                                        'order' => 330
                                       );

    $folder->add(
                 new EBox::Menu::Item(
                                      'url' => 'VPN/PPTP',
                                      'text' => 'PPTP',
                                      'order' => 40
                                     )
    );

    $root->add($folder);
}

# Method: widgets
#
# Overrides:
#
#      <EBox::Module::widgets>
#
sub widgets
{
    my ($self) = @_;

    if (not $self->isEnabled()) {
        return {};
    }

    my $widget = {
        'pptpusers' => {
            'title' => __('PPTP Connected Users'),
            'widget' => \&pptpWidget,
            'order' => 13,
            'default' => 1
        }
    };

    return $widget;
}

sub _who
{
    my ($self) = @_;

    return [] unless ($self->isEnabled());

    my $users = [];
    my @output;
    my $error;
    try {
        @output = @{ EBox::Sudo::root("last | grep 'still logged in'") };
    } otherwise {
        $error = 1;
    };

    return [] if ($error);

    for my $line (@output) {
        chomp($line);
        # test     ppp0         2011-07-11 22:50 (192.168.86.2) << old output by who
        # test     ppp0         92.75.124.210    Fri Sep 13 15:10   still logged in << new output by last
        my ($username, $terminal, $remote, $weekday, $month, $day, $time) = split '\s+', $line, 8;
        if ($terminal =~ m/^ppp\d+$/) {
            my $user = {};
            $user->{'username'} = $username;
            $user->{'iface'} = $terminal;
            $user->{'date'} = "$weekday-$month-$day $time";
            $user->{'ipaddr'} = $remote;
            push(@{$users}, $user);
        }
    }

    return $users;
}

sub pptpWidget
{
    my ($self, $widget) = @_;

    my $section = new EBox::Dashboard::Section('pptpusers');
    $widget->add($section);
    my $titles = [__('User'),  __('Interface'), __('Connected since'), __('Local IP address')];

    my $users = $self->_who();

    my $rows = {};
    foreach my $user (@{$users}) {
       my $id = $user->{'username'} . '_' . $user->{'ipaddr'};
       $rows->{$id} = [$user->{'username'}, $user->{'iface'},
                       $user->{'date'}, $user->{'ipaddr'}];
    }
    my $ids = [sort keys %{$rows}];
    $section->add(new EBox::Dashboard::List(undef, $titles, $ids, $rows,
                  __('No users connected.')));
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
    return EBox::PPTPLogHelper->new($self, @params);
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
                  from_ip   => __(q{Remote IP}),
                 };
    my @order = qw(timestamp event from_ip );

    my $events = {
                  initialized => __('Initialization sequence completed'),

                  connectionInitiated => __('Client connection initiated'),
                  connectionReset     => __('Client connection terminated'),
                 };

    return [{
            'name'      => $self->printableName(),
            'tablename' => 'pptp',
            'titles'    => $titles,
            'order'     => \@order,
            'timecol'   => 'timestamp',
            'filter'    => ['from_ip'],
            'types'     => { 'from_ip' => 'IPAddr' },
            'events'    => $events,
            'eventcol'  => 'event'
           }];
}

1;
