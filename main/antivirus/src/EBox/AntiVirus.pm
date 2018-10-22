# Copyright (C) 2009-2014 Zentyal S.L.
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

package EBox::AntiVirus;

use base qw(EBox::Module::Service
            EBox::FirewallObserver);

use Perl6::Junction qw(any);
use File::Slurp qw(read_file write_file);
use File::ReadBackwards;

use EBox::AntiVirus::FirewallHelper;
use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::Service;
use EBox::Exceptions::Internal;

use constant {
  CLAMD_CONF_FILE               => '/etc/clamav/clamd.conf',
  CLAMD_SOCKET                  => '/var/run/clamav/clamd.ctl',

  FRESHCLAM_CONF_FILE           => '/etc/clamav/freshclam.conf',
  FRESHCLAM_CRON_FILE           => '/etc/cron.d/clamav-freshclam',
  FRESHCLAM_DIR                 => '/var/lib/clamav/',
  FRESHCLAM_LOG_FILE            => '/var/log/clamav/freshclam.log',
  FRESHCLAM_USER                => 'clamav',
};

use constant APPARMOR_D => '/etc/apparmor.d/';
use constant {
    APPARMOR_FRESHCLAM => APPARMOR_D . 'local/usr.bin.freshclam',
    APPARMOR_CLAMD     => APPARMOR_D . 'usr.sbin.clamd',
};

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
#        <EBox::AntiVirus> - the recently created module
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'antivirus',
                                      printableName => __('Antivirus'),
                                      @_);
    bless($self, $class);
    return $self;
}

# Group: Public methods

# Method: enableService
#
#   Used to enable a service We have to verride this because squid needs a
#   notification of when the antivirus is enabled
#
# Parameters:
#
#   boolean - true to enable, false to disable
#
#  Overrides:
#      <EBox::Module::Service::enableService>
sub enableService
{
    my ($self, $status) = @_;
    defined $status or
        $status = 0;

    return unless ($self->isEnabled() xor $status);

    $self->SUPER::enableService($status);

    # notify squid of changes..
    #  this must be after status has chenged..
    my $global = EBox::Global->instance();
    if ($global->modExists('squid')) {
        my $squid = $global->modInstance('squid');
        $squid->notifyAntivirusEnabled();
    }
}

# Method: appArmorProfiles
#
#   Overrides to set the local AppArmor profile to allow freshclam
#   notification to Antivirus package
#
# Overrides:
#
#    <EBox::Module::Base::appArmorProfiles>
#
sub appArmorProfiles
{
    my ($self) = @_;

    return [{
        'binary' => 'usr.bin.freshclam',
        'local'  => 1,
        'file'   => 'antivirus/freshclam.profile.mas',
    }];
}

sub usedFiles
{
    return [
        {
            file => CLAMD_CONF_FILE,
            reason => __(' To configure clamd daemon'),
            module => 'antivirus',
        },
        {
            file => FRESHCLAM_CONF_FILE,
            reason => __('To schedule the launch of the updater'),
            module => 'antivirus',
        },
        {
            file   => APPARMOR_FRESHCLAM,
            reason => __x('Custom {app} profile configuration '
                          . 'for {bin} binary',
                          app => 'AppArmor', bin => 'freshclam'),
            module => 'antivirus',
        },
        {
            file   => APPARMOR_CLAMD,
            reason => __x('Disable {app} profile for {bin} binary',
                          app => 'AppArmor', bin => 'clamd'),
            module => 'antivirus',
        },
    ];
}

sub _daemons
{
    return [ { name => 'clamav-daemon' } ];
}

# Method: _daemonsToDisable
#
# Overrides:
#
#   <EBox::Module::Service::_daemonsToDisable>
#
sub _daemonsToDisable
{
    return [ { 'name' => 'clamav-freshclam', 'type' => 'init.d' } ];
}


sub localSocket
{
    return CLAMD_SOCKET;
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

    my $localSocket = $self->localSocket();

    my @clamdParams = (localSocket => $localSocket);

    unless ($self->global()->communityEdition()) {
        push (@clamdParams, paths => $self->model('Paths')->includes());
    }

    $self->writeConfFile(CLAMD_CONF_FILE, "antivirus/clamd.conf.mas", \@clamdParams);

    $self->disableApparmorProfile('usr.sbin.clamd');

    my $network = EBox::Global->modInstance('network');
    my $proxy = $network->model('Proxy');
    my @freshclamParams = (
            clamdConfFile   => CLAMD_CONF_FILE,
            proxyServer => $proxy->serverValue(),
            proxyPort => $proxy->portValue(),
            proxyUser => $proxy->usernameValue(),
            proxyPasswd => $proxy->passwordValue(),
            );

    $self->writeConfFile(FRESHCLAM_CONF_FILE,
            "antivirus/freshclam.conf.mas", \@freshclamParams);

    # Regenerate freshclam cron daily script
    $self->writeConfFile(FRESHCLAM_CRON_FILE,
                         'antivirus/clamav-freshclam.cron.mas',
                         [ enabled => $self->isEnabled() ]);
}

sub firewallHelper
{
    my ($self) = @_;

    if ($self->isEnabled()) {
        return EBox::AntiVirus::FirewallHelper->new();
    }

    return undef;
}

# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
    my ($self, $root) = @_;

    return if $self->global()->communityEdition();

    $root->add(new EBox::Menu::Item(text      => __('Antivirus'),
                                    url       => 'Antivirus/Composite/General',
                                    icon      => 'antivirus',
                                    order     => 900));
}

1;
