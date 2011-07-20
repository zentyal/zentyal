# Copyright (C) 2008-2010 eBox Technologies S.L.
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

package EBox::NTP;

use strict;
use warnings;

use base qw(EBox::Module::Service EBox::Model::ModelProvider
            EBox::Model::CompositeProvider);

use EBox::Objects;
use EBox::Gettext;
use EBox::Service;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use Error qw(:try);
use EBox::Validate qw(:all);
use EBox::Sudo;
use EBox;

use constant NTPCONFFILE => '/etc/ntp.conf';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'ntp',
                                      printableName => 'NTP',
                                      @_);
    bless($self, $class);
    return $self;
}

# Method: modelClasses
#
# Overrides:
#
#      <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [
        'EBox::NTP::Model::Settings',
        'EBox::NTP::Model::Servers',
    ];
}

# Method: compositeClasses
#
# Overrides:
#
#      <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{
    return [
        'EBox::NTP::Composite::General',
    ];
}

sub isRunning
{
    my ($self) = @_;
    # return undef if service is not enabled
    # otherwise it might be misleading if time synchronization is set
    ($self->isEnabled()) or return undef;
    return EBox::Service::running('ebox.ntpd');
}

# Method: actions
#
#   Override EBox::Module::Service::actions
#
sub actions
{
    return [
    {
        'action' => __('Remove ntp init script links'),
        'reason' => __('Zentyal will take care of starting and stopping ' .
                        'the services.'),
        'module' => 'ntp'
    }
    ];
}


# Method: usedFiles
#
#   Override EBox::Module::Service::usedFiles
#
sub usedFiles
{
    return [
            {
             'file' => NTPCONFFILE,
             'module' => 'ntp',
             'reason' => __('NTP configuration file')
            }
           ];
}

# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    # Create default rules and services and add default servers
    # only if installing the first time
    unless ($version) {
        my $servers = $self->model('Servers');
        for my $i (0..2) {
            $servers->add(server => "$i.pool.ntp.org");
        }

        my $firewall = EBox::Global->modInstance('firewall');
        $firewall->addInternalService(
                    'name' => 'ntp',
                    'description' => 'NTP',
                    'protocol' => 'udp',
                    'sourcePort' => 'any',
                    'destinationPort' => 123,
                );

        $firewall->saveConfigRecursive();
    }
}

sub _enforceServiceState
{
    my ($self) = @_;

    if (($self->isEnabled() or $self->synchronized) and $self->isRunning()) {
        EBox::Service::manage('ebox.ntpd','stop');
        sleep 2;
        if ($self->synchronized) {
            my $exserver = $self->firstServer();
            try {
                EBox::Sudo::root("/usr/sbin/ntpdate $exserver");
            } catch EBox::Exceptions::Internal with {
                EBox::warn("Couldn't execute ntpdate $exserver");
            };
        }
        EBox::Service::manage('ebox.ntpd','start');
    } elsif ($self->isEnabled() or $self->synchronized) {
        if ($self->synchronized) {
            my $exserver = $self->firstServer();
            try {
                EBox::Sudo::root("/usr/sbin/ntpdate $exserver");
            } catch EBox::Exceptions::Internal with {
                EBox::warn("Couldn't execute ntpdate $exserver");
            };
        }
        EBox::Service::manage('ebox.ntpd','start');
    } elsif ($self->isRunning) {
        EBox::Service::manage('ebox.ntpd','stop');
        if ($self->synchronized) {
            EBox::Service::manage('ebox.ntpd','start');
        }
    }
}

sub _stopService
{
    EBox::Service::manage('ebox.ntpd','stop');
}

sub _configureFirewall
{
    my ($self) = @_;

    my $fw = EBox::Global->modInstance('firewall');

    if ($self->synchronized) {
        $fw->addOutputRule('udp', 123);
    } else {
        $fw->removeOutputRule('udp', 123);
    }
}

# Method: setService
#
#       Enable/Disable the ntp service
#
# Parameters:
#
#       enabled - boolean. True enable, undef disable
#
sub setService # (active)
{
    my ($self, $active) = @_;

    ($active and $self->isEnabled()) and return;
    (!$active and !$self->isEnabled()) and return;
    $self->enableService($active);
    $self->_configureFirewall;
}

# Method: synchronized
#
#      Enable/disable the synchronization service to external ntp servers
#
# Returns:
#
#      boolean -  True enable, undef disable
#
sub synchronized
{
    my ($self) = @_;

    my $sync = $self->model('Settings')->syncValue();
    if (defined($sync) and ($sync == 0)) {
        $sync = undef;
    }
    return $sync;
}

# Method: servers
#
#   Returns the list of external ntp servers
#
# Returns:
#
#   array - holding the ntp servers
sub servers
{
    my ($self) = @_;

    my $model = $self->model('Servers');
    my @servers =
        map { $model->row($_)->valueByName('server') } @{$model->ids()};

    return @servers;
}

# Method: firstServer
#
#  Returns the first external NTP server
sub firstServer
{
    my ($self) = @_;
    my @servers = $self->servers();
    return $servers[0];
}

# Method: _setConf
#
#       Overrides base method. It writes the NTP configuration
#
sub _setConf
{
    my ($self) = @_;

    my @array = ();
    my @servers = $self->servers;
    my $synch = 'no';
    my $active = 'no';

    ($self->synchronized) and $synch = 'yes';
    ($self->isEnabled()) and $active = 'yes';

    push(@array, 'active'   => $active);
    push(@array, 'synchronized'  => $synch);
    push(@array, 'servers'  => \@servers);

    $self->writeConfFile(NTPCONFFILE, "ntp/ntp.conf.mas", \@array);
}

# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('text' => $self->printableName(),
                                    'url' => 'NTP/Composite/General',
                                    'separator' => 'Infrastructure',
                                    'order' => 445));
}

1;
