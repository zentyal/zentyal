# Copyright (C) 2013 Zentyal S.L.

use strict;
use warnings;

package EBox::SOGO;

use base qw(EBox::Module::Service);

use EBox::Gettext;
use EBox::Service;
use EBox::Sudo;
use EBox::Config;
use EBox::WebServer;

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
        my $webserverMod = $self->global()->modInstance('webserver');
        my $sysinfoMod = $global->modInstance('sysinfo');
        my @params = ();
        push (@params, hostname => $sysinfoMod->fqdn());
        push (@params, sslPort  => $webserverMod->listeningHTTPSPort());

        $self->writeConfFile("/etc/conf-available/zentyal-sogo.conf", "sogo/zentyal-sogo.mas", \@params);
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
             'action' => __('Create MySQL webmail database.'),
             'reason' => __('This database will store the data needed by the webmail service.'),
             'module' => 'sogo'
            },
            {
             'action' => __('Add webmail link to www data directory.'),
             'reason' => __('WebMail UI will be accesible at http://ip/webmail/.'),
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
        throw EBox::Exceptions::External(__x('Webmail module needs IMAP or IMAPS service enabled if ' .
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
    }
}

1;
