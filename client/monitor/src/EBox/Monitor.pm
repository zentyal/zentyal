# Copyright 2008 (C) eBox Technologies S.L.
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

# Class: EBox::Monitor
#
#   This module is intended to monitor several standard things among
#   others:
#
#      - cpu
#      - load
#      - processes
#      - swap
#      - memory usage
#      - disk usage
#

package EBox::Monitor;

use strict;
use warnings;

use base qw(EBox::GConfModule EBox::Model::ModelProvider
            EBox::ServiceModule::ServiceInterface);


use EBox::Validate qw( :all );
use EBox::Global;
use EBox::Gettext;
use EBox::Service;
use EBox::Sudo;

use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;

# Constants
use constant COLLECTD_SERVICE   => 'ebox.collectd';
use constant COLLECTD_CONF_FILE => '/etc/collectd/collectd.conf';
use constant RRD_BASE_DIR       => EBox::Config::lib() . '/collectd/rrd/';

# Method: _create
#
# Overrides:
#
#       <Ebox::Module::_create>
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'monitor',
                                      printableName => __('Monitor'),
                                      domain => 'ebox-monitor',
                                      @_);
    bless($self, $class);
    return $self;
}

# Group: Public methods

# Method: domain
#
# Overrides:
#
#       <EBox::Module::domain>
#
sub domain
{
    return 'ebox-monitor';
}

# Method: modelClasses
#
# Overrides:
#
#       <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [];
}

# Method: actions
#
# Overrides:
#
#       <EBox::ServiceModule::ServiceInterface::actions>
#
sub actions
{
    return [];
}


# Method: usedFiles
#
# Overrides:
#
#       <EBox::ServiceModule::ServiceInterface::usedFiles>
#
sub usedFiles
{
    return [
        { file   => COLLECTD_CONF_FILE,
          module => 'monitor',
          reason => __('Collectd configuration file'),
        },
       ];
}

# Method: enableActions
#
# Overrides:
#
#       <EBox::ServiceModule::ServiceInterface::enableActions>
#
sub enableActions
{
    EBox::Sudo::root(EBox::Config::share() . '/ebox-monitor/ebox-monitor-enable');
}

# Method: serviceModuleName
#
# Overrides:
#
#       <EBox::ServiceModule::ServiceInterface::serviceModuleName>
#
sub serviceModuleName
{
    return 'monitor';
}

# Method: isRunning
#
# Overrides:
#
#       <EBox::ServiceModule::ServiceInterface::isRunning>
#
sub isRunning
{
    return EBox::Service::running(COLLECTD_SERVICE);
}

# Method: statusSummary
#
# Overrides:
#
#     <EBox::Module::statusSummary>
#
# Returns:
#
#   <EBox::Summary::Status> - the summary components
#
sub statusSummary
{
    my ($self) = @_;
    return new EBox::Summary::Status('monitor', 'Monitor',
                                     $self->isRunning(),
                                     $self->isEnabled());
}

# Method: menu
#
# Overrides:
#
#    <EBox::Module method>
#
sub menu
{
    my ($self, $root) = @_;
#     my $item = new EBox::Menu::Item(
#         'url' => 'Monitor/View/Settings',
#         'text' => __('Monitor'),
#         'order' => 3);
#     $root->add($item);
}

# Method: RRDBaseDirPath
#
#      Return the RRD base directory path
#
# Returns:
#
#      String - the RRD base directory Path
#
sub RRDBaseDirPath
{
    return RRD_BASE_DIR;
}

# Group: Protected methods

# Method: _stopService
#
# Overrides:
#
#       <EBox::Module::_stopService>
#
sub _stopService
{
    EBox::Service::manage(COLLECTD_SERVICE, 'stop');
}

# Method: _regenConfig
#
#      It regenertates the monitor service configuration
#
# Overrides:
#
#      <EBox::Module::_regenConfig>
#
sub _regenConfig
{
    my ($self) = @_;

    $self->_setMonitorConf();
    $self->_doDaemon();

}

# Group: Private methods

# Method: _setMonitorConf
#
#    Set collectd.conf file
#
sub _setMonitorConf
{
    my ($self) = @_;

    $self->writeConfFile(COLLECTD_CONF_FILE,
                         'monitor/collectd.conf.mas');

}

# Method: _doDaemon
#
#    Set status for collectd daemon
#
sub _doDaemon
{
    my ($self) = @_;

    if ($self->isEnabled() and $self->isRunning()) {
        EBox::Service::manage(COLLECTD_SERVICE,'restart');
    } elsif ($self->isEnabled()) {
        EBox::Service::manage(COLLECTD_SERVICE,'start');
    } elsif (not $self->isEnabled() and $self->isRunning()) {
        EBox::Service::manage(COLLECTD_SERVICE,'stop');
    }

}

1;
