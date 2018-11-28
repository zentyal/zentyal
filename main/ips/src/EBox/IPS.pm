# Copyright (C) 2009-2013 Zentyal S.L.
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

# Class: EBox::IPS
#
#      Class description
#

use strict;
use warnings;

package EBox::IPS;

use base qw(EBox::Module::Service EBox::LogObserver EBox::FirewallObserver);

use TryCatch;

use EBox::Gettext;
use EBox::Service;
use EBox::Sudo;
use EBox::Exceptions::Sudo::Command;
use EBox::Exceptions::Internal;
use EBox::IPS::LogHelper;
use EBox::IPS::FirewallHelper;
use POSIX;

use constant SURICATA_CONF_FILE    => '/etc/suricata/suricata-debian.yaml';
use constant SURICATA_DEFAULT_FILE => '/etc/default/suricata';
use constant SURICATA_INIT_FILE    => '/etc/init/suricata.conf';
use constant SNORT_RULES_DIR       => '/etc/snort/rules';
use constant SURICATA_RULES_DIR    => '/etc/suricata/rules';

# Group: Protected methods

# Constructor: _create
#
#        Create an module
#
# Overrides:
#
#        <EBox::Module::Service::_create>
#
# Returns:
#
#        <EBox::IPS> - the recently created module
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'ips',
                                      printableName => __('IDS/IPS'),
                                      @_);
    bless($self, $class);
    return $self;
}

# Method: _daemons
#
# Overrides:
#
#       <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        {
         'name'         => 'suricata',
         'precondition' => \&_suricataNeeded,
        }
    ];
}

# Method: _suricataNeeded
#
#     Returns true if there are interfaces to listen, false otherwise.
#
sub _suricataNeeded
{
    my ($self) = @_;

    return 0 unless $self->isEnabled();

    return (@{$self->enabledIfaces()} > 0);
}

# Method: enabledIfaces
#
#   Returns array reference with the enabled interfaces that
#   are not unset or trunk.
#
sub enabledIfaces
{
    my ($self) = @_;

    my $net = EBox::Global->modInstance('network');
    my $ifacesModel = $self->model('Interfaces');
    my @ifaces;
    foreach my $row (@{$ifacesModel->enabledRows()}) {
        my $iface = $ifacesModel->row($row)->valueByName('iface');
        my $method = $net->ifaceMethod($iface);
        next if (($method eq 'notset') or ($method eq 'trunk') or ($method eq 'bundled'));
        push (@ifaces, $iface);
    }

    return \@ifaces;
}

# Method: nfQueueNum
#
#     Get the NFQueue number for perform inline IPS.
#
# Returns:
#
#     Int - between 0 and 65535
#
# Exceptions:
#
#     <EBox::Exceptions::Internal> - thrown if the value to return is
#     greater than 65535
#
sub nfQueueNum
{
    my ($self) = @_;

    my $queueNum = (EBox::Config::configkey('ips_nfqueue') or 0);
    if ($queueNum > 65535) {
        throw EBox::Exceptions::Internal('There are too many interfaces to set a valid NFQUEUE number');
    }
    return $queueNum;
}

# Method: fwPosition
#
#     IPS inline firewall position determined by ips_fw_position
#     configuration key
#
# Returns:
#
#     front  - if the all traffic should be analysed
#     behind - if only not explicitly accepted/denied traffic should be analysed
#              (*Default value*)
#
sub fwPosition
{
    my ($self) = @_;

    my $where = EBox::Config::configkey('ips_fw_position');
    if (defined ($where) and (($where eq 'front') or ($where eq 'behind'))) {
        return $where;
    } else {
        # Default value
        return 'behind';
    }
}

sub _setRules
{
    my ($self) = @_;

    my $snortDir = SNORT_RULES_DIR;
    my $suricataDir = SURICATA_RULES_DIR;
    my @cmds = ("mkdir -p $suricataDir", "rm -f $suricataDir/*");

    my $rulesModel = $self->model('Rules');
    my @rules;

    foreach my $id (@{$rulesModel->enabledRows()}) {
        my $row = $rulesModel->row($id);
        my $name = $row->valueByName('name');
        my $decision = $row->valueByName('decision');
        if ($decision =~ /log/) {
            push (@cmds, "cp $snortDir/$name.rules $suricataDir/");
            push (@rules, $name);
        }
        if ($decision =~ /block/) {
            push (@cmds, "cp $snortDir/$name.rules $suricataDir/$name-block.rules");
            push (@cmds, "sed -i 's/^alert /drop /g' $suricataDir/$name-block.rules");
            push (@rules, "$name-block");
        }
    }

    EBox::Sudo::root(@cmds);

    return \@rules;
}

# Method: _setConf
#
#       Regenerate the configuration
#
# Overrides:
#
#       <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    my $rules = $self->_setRules();
    my $mode  = 'accept';
    if ($self->fwPosition() eq 'front') {
        $mode = 'repeat';
    }

    $self->writeConfFile(SURICATA_CONF_FILE, 'ips/suricata-debian.yaml.mas',
                         [ mode => $mode, rules => $rules ]);

    $self->writeConfFile(SURICATA_DEFAULT_FILE, 'ips/suricata.mas',
                         [ enabled => $self->isEnabled(),
                           nfQueueNum => $self->nfQueueNum() ]);

    # workaround for broken systemd service, enforce use of init.d script
    my $systemdsvc = '/lib/systemd/system/suricata.service';
    if (-f $systemdsvc) {
        EBox::Sudo::silentRoot("rm -f $systemdsvc",
                               'systemctl daemon-reload');
    }
}

# Group: Public methods

# Method: menu
#
#       Add an entry to the menu with this module
#
# Overrides:
#
#       <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;
    $root->add(new EBox::Menu::Item('url' => 'IPS/Composite/General',
                                    'text' => $self->printableName(),
                                    'icon' => 'ips',
                                    'order' => 510));
}

# Method: usedFiles
#
#        Indicate which files are required to overwrite to configure
#        the module to work. Check overriden method for details
#
# Overrides:
#
#        <EBox::Module::Service::usedFiles>
#
sub usedFiles
{
    return [
        {
            'file' => SURICATA_CONF_FILE,
            'module' => 'ips',
            'reason' => __('Add rules to suricata configuration')
        },
        {
            'file' => SURICATA_DEFAULT_FILE,
            'module' => 'ips',
            'reason' => __('Enable start of suricata daemon')
        }
    ];
}

# Method: logHelper
#
# Overrides:
#
#       <EBox::LogObserver::logHelper>
#
sub logHelper
{
    my ($self) = @_;

    return (new EBox::IPS::LogHelper);
}

# Method: tableInfo
#
#       Two tables are created:
#
#           - ips_event for IPS events
#
# Overrides:
#
#       <EBox::LogObserver::tableInfo>
#
sub tableInfo
{
    my ($self) = @_ ;

    my $titles = {
                  'timestamp'   => __('Date'),
                  'priority'    => __('Priority'),
                  'description' => __('Description'),
                  'source'      => __('Source'),
                  'dest'        => __('Destination'),
                  'protocol'    => __('Protocol'),
                  'event'       => __('Event'),
                 };

    my @order = qw(timestamp priority description source dest protocol event);

    my $tableInfos = [
        {
            'name' => __('IPS'),
            'tablename' => 'ips_event',
            'titles' => $titles,
            'order' => \@order,
            'timecol' => 'timestamp',
            'events' => { 'alert' => __('Alert') },
            'eventcol' => 'event',
            'filter' => ['priority', 'description', 'source', 'dest'],
        } ];

    return $tableInfos;
}

sub firewallHelper
{
    my ($self) = @_;

    return ($self->_suricataNeeded() ? EBox::IPS::FirewallHelper->new() : undef);
}

1;
