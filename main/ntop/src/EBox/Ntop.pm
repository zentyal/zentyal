# Copyright (C) 2013 Zentyal S.L.
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

use base qw(EBox::Module::Service);

use EBox::Config;
use EBox::Gettext;
use EBox::Sudo;

# Constants
use constant NTOPNG_UPSTART_JOB => 'zentyal.ntopng';
use constant NTOPNG_CONF_FILE   => '/etc/ntopng/ntopng.conf';
use constant NTOPNG_DATA_DIR    => EBox::Config::var() . 'lib/ntopng';

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
                         [
                             ifaces        => [ 'any' ],
                             dataDir       => $dataDir,
                             localNetworks => $self->model('LocalNetworks')->networkIPAddresses(),
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


# Group: Private methods

1;
