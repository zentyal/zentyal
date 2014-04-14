# Copyright (C) 2013-2014 Zentyal S.L.
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

# Class: EBox::Ntop
#
#      Module to manage ntopng software to provide network monitoring
#      with application disection.
#

use strict;
use warnings;

package EBox::Ntop;

use base qw(EBox::Module::Service EBox::RedirectHelper);

use EBox::Config;
use EBox::Gettext;
use EBox::NetWrappers;
use EBox::Sudo;

# Constants
use constant NTOPNG_UPSTART_JOB => 'zentyal.ntopng';
use constant NTOPNG_CONF_FILE   => '/etc/ntopng/ntopng.conf';
use constant NTOPNG_DATA_DIR    => EBox::Config::var() . 'lib/ntopng';
use constant NTOPNG_PORT        => 3000;
use constant PRIVATE_NETWORKS => qw(10.0.0.0/8 172.16.0.0/12 192.168.0.0/16);

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
#        <EBox::Ntop> - the recently created module
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'ntop',
                                      printableName => __('Network Monitoring'),
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
         'name' => NTOPNG_UPSTART_JOB,
         'type' => 'upstart',
        }
    ];
}

# Method: _setConf
#
#       Regenerate the configuration for ntopng
#
# Overrides:
#
#       <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    my $dataDir = NTOPNG_DATA_DIR;
    unless (-d $dataDir) {
        EBox::Sudo::root("mkdir '$dataDir'", "chown nobody:nogroup '$dataDir'");
    }

    $self->writeConfFile(NTOPNG_CONF_FILE, 'ntop/ntopng.conf.mas',
                         [ ifaces        => $self->model('Interfaces')->ifacesToMonitor(),
                           dataDir       => $dataDir,
                           localNetworks => $self->_localNetworks(),
                           debug         => EBox::Config::boolean('debug'),
                         ]);
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
    $root->add(new EBox::Menu::Item('url' => 'Ntop/Composite/General',
                                    'text' => $self->printableName(),
                                    'icon' => 'ntop',
                                    'separator' => 'Gateway',
                                    'order' => 230));
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
            'file' => NTOPNG_CONF_FILE,
            'module' => 'ntop',
            'reason' => __('Set ntopng configuration'),
        },
    ];
}

# Method: initialSetup
#
#   Set the Ntop UI service and it is denied to internal networks by default
#
# Overrides:
#
#   <EBox::Module::Base::initialSetup>
#
sub initialSetup
{
    my ($self, $version) = @_;

    unless ($version) {
        my $services = EBox::Global->modInstance('services');

        my $serviceName = 'ntop_ui';
        unless ($services->serviceExists(name => $serviceName)) {
            $services->addMultipleService(
                name          => $serviceName,
                printableName => 'Ntop',
                description   => __('Ntop User Interface'),
                readOnly      => 1,
                services      => [ { protocol        => 'tcp',
                                     sourcePort      => 'any',
                                     destinationPort => NTOPNG_PORT } ]);
            $services->saveConfig();
        }
    }
}

# Group: <EBox::RedirectHelper> interface implementation

# Method: redirectionConf
#
#    Configuration for the redirection from Zentyal Remote if the host
#    is registered to Ntop UI
#
# Overrides:
#
#    <EBox::RedirectHelper>
#
sub redirectionConf
{
    return [ {
        url    => 'ntop',
        target => "http://localhost:" . NTOPNG_PORT,
        absolute_url_patterns => [ '^/(lua|bootstrap|js|css|img)/' ],
        referer_patterns      => [ '(ntop|lua)' ],
        query_string_patterns => [ '^page=Top' ],
    }, ]
}


# Group: Private methods

# Local networks are based on internal networks
# If there are not, then put all private classes
sub _localNetworks
{
    my ($self) = @_;

    my $net = $self->global()->modInstance('network');
    my $internalIfaces = $net->InternalIfaces();
    my @privateNetworks;
    if (@{$internalIfaces}) {
        foreach my $iface (@{$internalIfaces}) {
            push(@privateNetworks,
                 EBox::NetWrappers::to_network_with_mask($net->ifaceNetwork($iface), $net->ifaceNetmask($iface)));
        }
    } else {
        @privateNetworks = PRIVATE_NETWORKS;
    }
    return \@privateNetworks;
}

1;
