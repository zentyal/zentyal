# Copyright (C) 2014 Zentyal S.L.
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

package EBox::ActiveSync;

use base qw(EBox::Module::Service);

use EBox::Sudo;
use EBox::Config;
use EBox::Gettext;
use EBox::OpenChange;

# Method: _create
#
#   The constructor, instantiate module
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'activesync',
                                      printableName => 'ActiveSync',
                                      @_);
    bless ($self, $class);
    return $self;
}

# Method: actions
#
# Override:
#
#   <EBox::Module::Service::actions>
#
sub actions
{
    return [
        {
            'action' => __('Modify web server configuration'),
            'reason' => __('Redirect ActiveSync traffic to sogo daemon'),
            'module' => 'activesync',
        },
    ];
}

# Method: enableActions
#
#   Called when module is enabled for first time
#
# Override:
#
#   <EBox::Module::Service::enableActions>
#
sub enableActions
{
    my ($self) = @_;
    $self->SUPER::enableActions();

    my $confDir = EBox::Config::conf() . 'activesync';
    EBox::Sudo::root("mkdir -p '$confDir'");
}

# Method: enableService
#
#   Called when module is enabled or disabled
#
# Override:
#
#   <EBox::Module::Service::enableService>
#
sub enableService
{
    my ($self, $status) = @_;

    $self->SUPER::enableService($status);
    if ($self->changed()) {
        my $global = $self->global();

        # Mark webadmin as changed so we are sure nginx configuration is
        # refreshed with the new includes
        my $webAdmin = $global->modInstance('webadmin');
        $webAdmin->setAsChanged();
    }
}

# Method: _setConf
#
#   Set the module configuration.
#
# Override:
#
#   <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    return unless $self->configured();

    my $global = $self->global();
    my $openchange = $global->modInstance('openchange');
    return unless $openchange->isProvisioned();

    my $confDir = EBox::Config::conf() . 'activesync';
    my $nginxInclude = "$confDir/activesync.conf";

    my $webadmin = $global->modInstance('webadmin');
    if ($self->isEnabled()) {
        my $sysinfo = $global->modInstance('sysinfo');
        my $server = $sysinfo->hostDomain();
        my $incParams = [
            server => $server,
            sogoDaemonPort => EBox::OpenChange::SOGO_PORT(),
        ];
        $self->writeConfFile($nginxInclude,
                             'activesync/activesync.nginx.mas',
                             $incParams,
                             { uid => 0, gid => 0, mode => '644' }
                        );
        $webadmin->addNginxInclude($nginxInclude);
    } else {
        $webadmin->removeNginxInclude($nginxInclude);
    }
}

1;
