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

use strict;
use warnings;

package EBox::SOGO;

use base qw(EBox::Module::Service);

use EBox::Config;
use EBox::Exceptions::External;
use EBox::Exceptions::Sudo::Command;
use EBox::Gettext;
use EBox::Service;
use EBox::Sudo;
use EBox::WebServer;

use TryCatch::Lite;

use constant SOGO_APACHE_CONF => '/etc/apache2/conf-available/zentyal-sogo.conf';

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
#        <EBox::WebMail> - the recently created module
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'sogo',
                                      printableName => __('OpenChange Webmail'),
                                      @_);
    bless($self, $class);
    return $self;
}

# Method: _setConf
#
#        Regenerate the configuration
#
# Overrides:
#
#       <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    if ($self->isEnabled()) {
        my $global = $self->global();
        my $webserverMod = $global->modInstance('webserver');
        my $sysinfoMod = $global->modInstance('sysinfo');
        my @params = ();
        push (@params, hostname => $sysinfoMod->fqdn());
        push (@params, sslPort  => $webserverMod->listeningHTTPSPort());

        $self->writeConfFile(SOGO_APACHE_CONF, "sogo/zentyal-sogo.mas", \@params);
        try {
            EBox::Sudo::root("a2enconf zentyal-sogo");
        } catch (EBox::Exceptions::Sudo::Command $e) {
            # Already enabled?
            if ($e->exitValue() != 1) {
                $e->throw();
            }
        }
    } else {
        try {
            EBox::Sudo::root("a2disconf zentyal-sogo");
        } catch (EBox::Exceptions::Sudo::Command $e) {
            # Already disabled?
            if ($e->exitValue() != 1) {
                $e->throw();
            }
        }
    }

    # Force apache restart to refresh the new sogo configuration
    my $webserverMod = EBox::Global->modInstance('webserver');
    $webserverMod->restartService();
}

# Group: Public methods

# Method: actions
#
#        Explain the actions the module must make to configure the
#        system. Check overriden method for details
#
# Overrides:
#
#        <EBox::Module::Service::actions>
sub actions
{
    return [
            {
             'action' => __('Enable proxy, proxy_http and headers Apache 2 modules.'),
             'reason' => __('To make OpenChange Webmail be accesible at http://ip/SOGo/.'),
             'module' => 'sogo'
            },
    ];
}

# Method: enableActions
#
#        Run those actions explain by <actions> to enable the module
#
# Overrides:
#
#        <EBox::Module::Service::enableActions>
#
sub enableActions
{
    my ($self) = @_;

    my $mail = EBox::Global->modInstance('mail');
    unless ($mail->imap() or $mail->imaps()) {
        throw EBox::Exceptions::External(__x('OpenChange Webmail module needs IMAP or IMAPS service enabled if ' .
                                             'using Zentyal mail service. You can enable it at ' .
                                             '{openurl}Mail -> General{closeurl}.',
                                             openurl => q{<a href='/Mail/Composite/General'>},
                                             closeurl => q{</a>}));
    }

    # Execute enable-module script
    $self->SUPER::enableActions();

    # Force apache restart
    EBox::Global->modChange('webserver');
}

# Method: usedFiles
#
# Overrides:
#
# <EBox::Module::Service::usedFiles>
#
sub usedFiles
{
    return [
        {
            'file'   => SOGO_APACHE_CONF,
            'reason' => __('To make SOGo webmail available'),
            'module' => 'sogo'
        },
    ];
}

sub _daemons
{
    return [ { 'name' => 'sogo', 'type' => 'init.d' } ];
}

# Method: initialSetup
#
# Overrides:
#
#        <EBox::Module::Base::initialSetup>
#
sub initialSetup
{
    my ($self, $version) = @_;

    if ((defined ($version)) and (EBox::Util::Version::compare($version, '3.4.1') < 0)) {
        try {
            EBox::Sudo::root("a2dissite zentyal-sogo");
        } catch (EBox::Exceptions::Sudo::Command $e) {
            # Already disabled?
            if ($e->exitValue() != 1) {
                $e->throw();
            }
        }
        EBox::Sudo::silentRoot("rm -f /etc/apache2/sites-available/zentyal-sogo.conf");

        # Force a configuration dump
        $self->save();
    }
}

1;
