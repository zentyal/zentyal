# Copyright (C) 2011-2012 Zentyal S.L.
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
            EBox::Model::CompositeProvider
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
use constant DAEMON_PREFIX => 'zentyal.bwmonitor-';

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
        'EBox::BWMonitor::Model::BWUsage',
    ];
}

sub compositeClasses
{
    return [
        'EBox::BWMonitor::Composite::General',
    ];
}


# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder('name' => 'Network',
                                        'text' => __('Network'),
                                        'separator' => 'Core',
                                        'order' => 40);

    $folder->add(new EBox::Menu::Item('url' => 'Network/BWMonitor',
                                     'text' => $self->printableName(),
                                     'order' => 90));
    $root->add($folder);
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


# Method: userBWUsage
#
#   Returns total user bandwidth usage in bytes since the given timestmap
#
#   Parameters:
#       - username
#       - since (timestamp)
#
sub userExtBWUsage
{
    my ($self, $username, $since) = @_;

    my $db = EBox::DBEngineFactory::DBEngine();

    my @localtime = localtime($since);
    my $year = $localtime[5] + 1900;
    my $month = $localtime[4] + 1;
    my $mday = $localtime[3];
    my $hour = $localtime[2];
    my $min = $localtime[1];
    my $sec = $localtime[0];

    my $beg = "$year-$month-$mday $hour:$min:$sec";

    my $res = $db->query_hash({
            'select' => 'SUM(exttotalrecv) as recv, SUM(exttotalsent) as sent',
            'from' => 'bwmonitor_usage',
            'where' => qq{username='$username' and timestamp>'$beg'},
            'group' => 'username'
        });

    if ( @{$res} ) {
        return $res->[0]->{recv} + $res->[0]->{sent};
    } else {
        return 0;
    }
}


# Method: allUsersBWUsage
#
#   Returns total bandwidth usage in bytes since the given timestmap
#   for every user
#
#   Parameters:
#       - since (timestamp)
#
sub allUsersExtBWUsage
{
    my ($self, $since) = @_;

    my $db = EBox::DBEngineFactory::DBEngine();

    my @localtime = localtime($since);
    my $year = $localtime[5] + 1900;
    my $month = $localtime[4] + 1;
    my $mday = $localtime[3];
    my $hour = $localtime[2];
    my $min = $localtime[1];
    my $sec = $localtime[0];

    my $beg = "$year-$month-$mday $hour:$min:$sec";

    my $res = $db->query_hash({
            'select' => 'client as ip,' .
                        'SUM(exttotalrecv) as extrecv, SUM(exttotalsent) as extsent,' .
                        'SUM(inttotalrecv) as intrecv, SUM(inttotalsent) as intsent',
            'from' => 'bwmonitor_usage',
            'where' => qq{timestamp>'$beg'},
            'group' => 'client'
        });

    return $res;
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

    # delete old files
    EBox::Sudo::root("rm -f " . CONF_DIR . '/*.conf');
    EBox::Sudo::root("rm -f " . UPSTART_DIR . DAEMON_PREFIX . '*.conf');

    # Write daemon upstart and config files
    foreach my $iface (@{$self->ifaces()}) {
        my $name = DAEMON_PREFIX . $iface;
        EBox::Module::Base::writeConfFileNoCheck(UPSTART_DIR .  "$name.conf",
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

    foreach my $name (@{$self->_managedDaemons()}) {
        push @daemons, {
            name => $name
        };
    }

    return \@daemons;
}

sub _managedDaemons
{
    my ($self) = @_;
    my @daemons;
    opendir my $DH, UPSTART_DIR or
        throw EBox::Exceptions::Internal("Cannot open upstart dir: $!");

    my $prefix = DAEMON_PREFIX;
    my $isBwmonitor = qr/^$prefix.*\.conf$/;
    while (my $file =readdir($DH)) {
        if ($file =~ $isBwmonitor) {
            $file =~ s/\.conf//;
            push @daemons, $file;
        }
    }
    closedir $DH or
        throw EBox::Exceptions::Internal("Cannot close upstart dir: $!" );

    return \@daemons;
}

sub isRunning
{
    my ($self) = @_;
    my $running =  $self->SUPER::isRunning();
    if ($running) {
        # check for zero-daemons edge case
        my $nDaemons = @{ $self->_daemons() };
        if ($nDaemons == 0) {
            return $self->isEnabled();
        }
    }

    return $running;
}

# Override _enforceServiceState to stop disabled daemons
sub _enforceServiceState
{
    my ($self) = @_;

    try {
        $self->_stopService();
    } otherwise {};
    $self->_startService() if($self->isEnabled());
}


# Stop all daemons (also interfaces disabled in the GUI)
sub _stopService
{
    my ($self) = @_;
    foreach my $name (@{$self->_managedDaemons()}) {
        $self->_stopDaemon({ name => $name});
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

# Group: Report related methods

# Method: consolidateReportQueries
#
#     Consolidate bwmonitor_usage table to perform reports
#
# Overrides:
#
#     <EBox::Module::Base::consolidateReportQueries>
#
sub consolidateReportQueries
{
    return [
        {
            'target_table' => 'bwmonitor_usage_report',
            'query' => {
                'select' => q{
                  client, username, SUM(inttotalrecv) AS inttotalrecv,
                  SUM(inttotalsent) AS inttotalsent, SUM(inttcp) AS inttcp,
                  SUM(intudp) AS intudp, SUM(inticmp) AS inticmp,
                  SUM(exttotalrecv) AS exttotalrecv,
                  SUM(exttotalsent) AS exttotalsent, SUM(exttcp) AS exttcp,
                  SUM(extudp) AS extudp, SUM(exticmp) AS exticmp},
                'from'   => 'bwmonitor_usage',
                'group'  => 'client, username',
            },
            quote => { username => 1, client => 1 }
           },
       ];
}

# Method: report
#
# Overrides:
#
#     <EBox::Module::Base::report>
#
sub report
{
    my ($self, $beg, $end, $options) = @_;

    my $report = {};

    my $topClient = 10;
    if ( exists $options->{'max_top_client_bw_usage'} ) {
        $topClient = $options->{'max_top_client_bw_usage'};
    }

    $report->{top_client_bw_usage} = $self->runQuery(
        $beg, $end,
        {
            select => q{
                client,
                SUM(intTotalRecv) + SUM(intTotalSent) + SUM(extTotalRecv) + SUM(extTotalSent) AS total_bytes,
                SUM(intTotalRecv) + SUM(intTotalSent) AS int_total_bytes,
                SUM(extTotalRecv) + SUM(extTotalSent) AS ext_total_bytes},
            from   => 'bwmonitor_usage_report',
            group  => 'client',
            limit  => $topClient,
            order  => 'total_bytes DESC',
        });

    my $topUser = 10;
    if ( exists $options->{'max_top_user_bw_usage'} ) {
        $topUser = $options->{'max_top_user_bw_usage'};
    }

    $report->{top_user_bw_usage} = $self->runQuery(
        $beg, $end,
        {
            select => q{
                username,
                SUM(intTotalRecv) + SUM(intTotalSent) + SUM(extTotalRecv) + SUM(extTotalSent) AS total_bytes,
                SUM(intTotalRecv) + SUM(intTotalSent) AS int_total_bytes,
                SUM(extTotalRecv) + SUM(extTotalSent) AS ext_total_bytes},
            from   => 'bwmonitor_usage_report',
            group  => 'username',
            limit  => $topUser,
            order  => 'total_bytes DESC',
        });

    if ( defined($report->{top_user_bw_usage}->{username}) ) {
        if ( @{$report->{top_user_bw_usage}->{username}} <= 1 ) {
            # Do not send a top user with non authenticated users
            delete $report->{top_user_bw_usage};
        } else {
            # Rename undef user to unauthenticated user
            foreach my $username (@{$report->{top_user_bw_usage}->{username}}) {
                unless( defined($username) ) {
                    $username = '___non_auth___';
                    last;
                }
            }
        }
    }

    $report->{bw_usage_per_transport_protocol} = $self->runQuery(
        $beg, $end,
        {
            select => q{SUM(intTCP) + SUM(extTCP) AS tcp_bytes,
                        SUM(intUDP) + SUM(extUDP) AS udp_bytes,
                        SUM(intICMP) + SUM(extICMP) AS icmp_bytes,
                        SUM(intTotalSent) + SUM(intTotalRecv)
                          + SUM(extTotalSent) + SUM(extTotalRecv)
                          - SUM(intTCP) - SUM(extTCP) - sum(intUDP)
                          - SUM(extUDP) - SUM(intICMP) - SUM(extICMP) AS other_bytes},
            from   => 'bwmonitor_usage_report',
        });

    return $report;

}

# Group: Implement LogHelper interface
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
        'forceEnabled' => 1,
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
    $dataToInsert{username} = '';
    $dataToInsert{username} = $row->valueByName('username') if (defined($row));

    # Insert into db
    $dbengine->insert('bwmonitor_usage', \%dataToInsert);
}

1;
