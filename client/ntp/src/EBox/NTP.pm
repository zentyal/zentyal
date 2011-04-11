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

use base qw(EBox::Module::Service);

use EBox::Objects;
use EBox::Gettext;
use EBox::Service;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use Error qw(:try);
use EBox::Validate qw( :all );
use EBox::Sudo;
use EBox;

use constant NTPCONFFILE => "/etc/ntp.conf";

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'ntp', printableName => 'NTP',
                        domain => 'ebox-ntp',
                        @_);
    bless($self, $class);
    return $self;
}

sub isRunning
{
    my ($self) = @_;
    # return undef if service is not enabled
    # otherwise it might be misleading if time synchronization is set
    ($self->isEnabled()) or return undef;
    return EBox::Service::running('ebox.ntpd');
}

sub domain
{
    return 'ebox-ntp';
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

# Method: enableActions
#
#   Override EBox::Module::Service::enableActions
#
sub enableActions
{
    EBox::Sudo::root(EBox::Config::share() . '/ebox-ntp/ebox-ntp-enable');
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

# Method: setSynchronized
#
#      Enable/disable the synchronization service to external ntp servers
#
# Parameters:
#
#       enabled - boolean. True enable, undef disable
#
sub setSynchronized # (synchro)
{
    my ($self, $synchronized) = @_;

    ($synchronized and $self->synchronized) and return;
    (!$synchronized and !$self->synchronized) and return;
    $self->set_bool('synchronized', $synchronized);
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

    my $sync = $self->get_bool('synchronized');
    if (defined($sync) and ($sync == 0)) {
        $sync = undef;
    }
    return $sync;
}

# Method: setServers
#
#   Sets the external ntp servers to synchronize from
#
# Parameters:
#
#   server1 - primary server
#   server2 - secondary server
#   server3 - tertiary server
#
sub setServers # (server1, server2, server3)
{
    my ($self, $s1, $s2, $s3) = @_;

    if (!(defined $s1 and ($s1 ne''))) {
        throw EBox::Exceptions::DataMissing (data => __('Primary server'));
    }
    _checkServer($s1, __('primary server'));


    if (defined $s2 and ($s2 ne '')) {
        if ($s2 eq $s1) {
            throw EBox::Exceptions::External (__("Primary and secondary server must be different"))
        }

        _checkServer($s2, __('secondary server'));
    }
    else {
        if (defined($s3) and ($s3 ne "")) {
            throw EBox::Exceptions::DataMissing (data => __('Secondary server'));
        }

        $s2 = '';
    }

    if (defined $s3 and ($s3 ne '')) {
        if ($s3 eq $s1) {
            throw EBox::Exceptions::External (__("Primary and tertiary server must be different"))
        }
        if ($s3 eq $s2) {
            throw EBox::Exceptions::External (__("Primary and secondary server must be different"))
        }

        _checkServer($s3, __('tertiary server'));
    }
    else {
        $s3 = '';
    }

    $self->set_string('server1', $s1);
    $self->set_string('server2', $s2);
    $self->set_string('server3', $s3);
}

sub _checkServer
{
    my ($server, $serverName) = @_;

    if ($server =~ m/^[.0-9]*$/) {  # seems a IP address
        checkIP($server, __x('{name} IP address', name => $serverName));
    }
    else {
        checkDomainName($server, __x('{name} host name', name => $serverName));
    }
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

    my @servers = ($self->get_string('server1'),
            $self->get_string('server2'),
            $self->get_string('server3'));
    foreach my $server (0..2) {
        unless($servers[$server]) {
            $servers[$server] = "$server.pool.ntp.org";
        }
    }

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

sub _restartAllServices
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $failed = '';
    EBox::info('Restarting all modules');
    foreach my $mod (@{$global->modInstancesOfType('EBox::Module::Service')}) {
        my $name = $mod->name();
        next if ($name eq 'network') or
                ($name eq 'firewall');
        try {
            $mod->restartService();
        } catch EBox::Exceptions::Internal with {
            $failed .= "$name ";
        };
    }
    if ($failed ne "") {
        throw EBox::Exceptions::Internal("The following modules " .
            "failed while being restarted, their state is " .
            "unknown: $failed");
    }

    EBox::info('Restarting system logs');
    try {
        EBox::Sudo::root('service rsyslog restart',
                         'service cron restart');
    } catch EBox::Exceptions::Internal with {
    };
}

# Method: setNewDate
#
#   Sets the system date
#
# Parameters:
#
#   day -
#   month -
#   year -
#   hour -
#   minute -
#   second -
sub setNewDate # (day, month, year, hour, minute, second)
{
    my ($self, $day, $month, $year, $hour, $minute, $second) = @_;

    my $newdate = "$year-$month-$day $hour:$minute:$second";
    my $command = "/bin/date --set \"$newdate\"";
    EBox::Sudo::root($command);

    my $global = EBox::Global->getInstance(1);
    $self->_restartAllServices;
}

# Method: setNewTimeZone
#
#   Sets the system's time zone
#
# Parameters:
#
#   continent -
#   country -
sub setNewTimeZone # (continent, country)
{
    my ($self, $continent, $country) = @_;

    $self->set_string('continent', $continent);
    $self->set_string('country', $country);
    EBox::Sudo::root("echo $continent/$country > /etc/timezone");
    EBox::Sudo::root("cp -f /usr/share/zoneinfo/$continent/$country /etc/localtime");
}

# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder('name' => 'EBox',
                                        'text' => __('System'));

    $folder->add(new EBox::Menu::Item('url' => 'NTP/Datetime',
                                      'text' => __('Date/Time')));

    $folder->add(new EBox::Menu::Item('url' => 'NTP/Timezone',
                                      'text' => __('Time Zone')));
    $root->add($folder);
}

1;
