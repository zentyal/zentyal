# Copyright (C) 2011 eBox Technologies S.L.
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

package EBox::BWMonitor;

use strict;
use warnings;

use base qw(EBox::Module::Service
            EBox::Model::ModelProvider
            EBox::FirewallObserver
            EBox::LogObserver
            EBox::LogHelper);

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Menu::Item;
use Error qw(:try);
use EBox::Exceptions::External;

use constant CONF_DIR => EBox::Config::conf() . '/bwmonitor/';
use constant UPSTART_DIR => '/etc/init/';
use constant LOGS_DIR => '/var/log/zentyal/bwmonitor/';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'bwmonitor',
                                      printableName => __('Bandwidth Monitor'),
                                      @_);

    $self->{usermap} = $self->model('UserIPMap');

    bless($self, $class);
    return $self;
}

sub modelClasses
{
    return [
        'EBox::BWMonitor::Model::Interfaces',
        'EBox::BWMonitor::Model::UserIPMap',  # FIXME? this should reside in state
    ];
}

# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('url' => 'BWMonitor/View/Interfaces',
                                    'text' => $self->printableName(),
                                    'separator' => 'Gateway',
                                    'order' => 230));
}


# Method: addUserIP
#
#   Match an user with the given IP. Until further notice
#   from/to that IP will be assigned to the given user.
#   An user can have many assigned IPs so removeUserIP does not
#   modify previous calls (see removeUserIP)
#
#   Params:
#       - username
#       - ip
#
#   Throws Internal exception if the user-ip pair already exists
#
sub addUserIP
{
    my ($self, $username, $ip) = @_;

    my $changed = $self->changed();
    $self->{usermap}->add(username => $username, ip => $ip);
    $self->setAsChanged(0) unless ($changed);
}


# Method: removeUserIP
#
#   Ends a previously created match between user and IP if it exists
#
#   Params:
#       - username
#       - ip
#
sub removeUserIP
{
    my ($self, $username, $ip) = @_;

    my $row = $self->{usermap}->find(ip => $ip);
    return unless (defined($row));

    if ($row->valueByName('username') eq $username) {
        my $changed = $self->changed();
        $self->{usermap}->removeRow($row->id(), 1);
        $self->setAsChanged(0) unless ($changed);
    }
}



sub _setConf
{
    my ($self) = @_;

    my $network = EBox::Global->modInstance('network');

    # Get internal networks list
    my @internalNetworks;
    for my $iface (@{$network->InternalIfaces()}) {
        push (@internalNetworks, {
            ip => $network->ifaceNetwork($iface),
            netmask => $network->ifaceNetmask($iface)
        });
    }

    # Create confdir if it doesn't exists
    if (not -d CONF_DIR) {
        mkdir (CONF_DIR, 0755);
    }


    # Write daemon upstart and config files
    foreach my $iface (@{$self->ifaces()}) {
        EBox::Module::Base::writeConfFileNoCheck(UPSTART_DIR . "zentyal.bwmonitor-$iface.conf",
            "bwmonitor/upstart.mas",
            [ interface => $iface ]);

        EBox::Module::Base::writeConfFileNoCheck(CONF_DIR . "bwmonitor-$iface.conf",
            "bwmonitor/config.mas",
            [
                interface => $iface,
                networks => \@internalNetworks
            ]);
    }
}

sub _daemons
{
    my ($self) = @_;

    my @daemons;

    foreach my $iface (@{$self->ifaces()}) {
        push (@daemons, {
            name => "zentyal.bwmonitor-$iface"
        });
    }

    return \@daemons;
}

# Override _enforceServiceState to stop disabled daemons
sub _enforceServiceState
{
    my ($self) = @_;

    $self->_stopService();
    $self->_startService() if($self->isEnabled());
}


# Stop all daemons (also interfaces disabled in the GUI)
sub _stopService
{
    my ($self) = @_;

    my $model = $self->model('Interfaces');
    for my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $iface = $row->valueByName('interface');
        $self->_stopDaemon({ name => "zentyal.bwmonitor-$iface" });
    }
}


# Function: ifaces
#
#   Interfaces where bandwidth monitor is enabled
#
sub ifaces
{
    my ($self) = @_;
    my $model = $self->model('Interfaces');
    my @ifaces;

    for my $id (@{$model->enabledRows()}) {
        my $row = $model->row($id);
        push(@ifaces, $row->valueByName('interface'));
    }

    return \@ifaces;
}


# Implement LogHelper interface
sub tableInfo
{
    my ($self) = @_;

    my $titles = {
        'timestamp' => __('Date'),
        'client' => __('Client address'),
        'interface' => __('Interface'),
        'username' => __('User'),
        'exttotalrecv' => __('External recv'),
        'exttotalsent' => __('External sent'),
        'inttotalrecv' => __('Internal recv'),
        'inttotalsent' => __('Internal sent'),
    };

    my @order = qw(timestamp interface client username exttotalrecv exttotalsent inttotalrecv inttotalsent);

#   TODO consolidation...
#    my $consolidation = {
#
#    };

    return [{
        'name' => __('Bandwidth usage'),
        'index' => 'bwmonitor_usage',
        'titles' => $titles,
        'order' => \@order,
        'events' => {},
        'eventcol' => 'timestamp',
        'tablename' => 'bwmonitor_usage',
        'timecol' => 'timestamp',
        'filter' => ['client', 'interface'],
    }];
}


sub logHelper
{
    my ($self) = @_;
    return $self;
}


# Method: logFiles
#
#   This function must return the file or files to be read from.
#
# Returns:
#
#   array ref - containing the whole paths
#
sub logFiles
{
    my ($self) = @_;

    my @files;
    my $ifaces = $self->ifaces();
    foreach my $iface (@{$ifaces}) {
       push (@files, LOGS_DIR . "$iface.log");
    }

    return \@files;
}

# Method: processLine
#
#   This fucntion will be run every time a new line is recieved in
#   the associated file. You must parse the line, and generate
#   the messages which will be logged to ebox through an object
#   implementing EBox::AbstractLogger interface.
#
# Parameters:
#
#   file - file name
#   line - string containing the log line
#   dbengine- An instance of class implemeting AbstractDBEngineinterface
#
sub processLine
{
    my ($self, $file, $line, $dbengine) = @_;

    unless ($line =~ /^IP=(\d+\.\d+\.\d+\.\d+)( [A-Z_]+=\w+)+/) {
        return;
    }

    # retrive iface from log file
    my ($iface) = $file =~ /([^\/]+)\.log$/;

    # Parse log line
    my $data = { $line =~ /([A-Z_]+)=([0-9.]+)+/g };


    my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($data->{TIMESTAMP}))[0..5];
    ($mon,$year) = ($mon+1,$year+1900);

    my %dataToInsert;
    $dataToInsert{timestamp} = "$year-$mon-$mday $hour:$min:$sec";
    $dataToInsert{client} = $data->{IP};
    $dataToInsert{interface} = $iface;

    $dataToInsert{intTotalRecv} = $data->{INT_RECV};
    $dataToInsert{intTotalSent} = $data->{INT_SENT};
    $dataToInsert{intICMP} = $data->{INT_ICMP};
    $dataToInsert{intUDP} = $data->{INT_UDP};
    $dataToInsert{intTCP} = $data->{INT_TCP};

    $dataToInsert{extTotalRecv} = $data->{EXT_RECV};
    $dataToInsert{extTotalSent} = $data->{EXT_SENT};
    $dataToInsert{extICMP} = $data->{EXT_ICMP};
    $dataToInsert{extUDP} = $data->{EXT_UDP};
    $dataToInsert{extTCP} = $data->{EXT_TCP};

    # Retrieve username
    my $row = $self->{usermap}->find(ip => $data->{IP});
    $dataToInsert{username} = $row->valueByName('username') if (defined($row));


    # Insert into db
    $dbengine->insert('bwmonitor_usage', \%dataToInsert);
}

1;
