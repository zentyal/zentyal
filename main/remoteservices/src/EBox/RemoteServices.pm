# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::RemoteServices;

use base qw(EBox::Module::Service
            EBox::NetworkObserver
            EBox::Events::DispatcherProvider
            EBox::FirewallObserver);

# Class: EBox::RemoteServices
#
#      RemoteServices module to handle everything related to the remote
#      services offered
#

use feature qw(switch);

use Data::UUID;
use Date::Calc;
use EBox::Config;
use EBox::Dashboard::ModuleStatus;
use EBox::Dashboard::Section;
use EBox::Dashboard::Value;
use EBox::DBEngineFactory;
use EBox::Exceptions::DeprecatedMethod;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::NotConnected;
use EBox::Event;
use EBox::Gettext;
use EBox::Global;
use EBox::GlobalImpl;
use EBox::Service;
use EBox::RemoteServices::AdminPort;
use EBox::RemoteServices::Audit::Password;
use EBox::RemoteServices::Auth;
use EBox::RemoteServices::Backup;
use EBox::RemoteServices::Bundle;
use EBox::RemoteServices::Capabilities;
use EBox::RemoteServices::Connection;
use EBox::RemoteServices::Configuration;
use EBox::RemoteServices::Cred;
use EBox::RemoteServices::Exceptions::NotCapable;
use EBox::RemoteServices::Subscription;
use EBox::RemoteServices::SupportAccess;
use EBox::RemoteServices::FirewallHelper;
use EBox::RemoteServices::RESTClient;
use EBox::RemoteServices::QAUpdates;
use EBox::Sudo;
use EBox::Util::Version;
use EBox::Validate;
use TryCatch::Lite;
use File::Slurp;
use JSON::XS;
use Net::DNS;
use POSIX;
use YAML::XS;

# Constants
use constant SERV_DIR            => EBox::Config::conf() . 'remoteservices/';
use constant SUBS_DIR            => SERV_DIR . 'subscription/';
use constant WS_DISPATCHER       => __PACKAGE__ . '::WSDispatcher';
use constant RUNNERD_SERVICE     => 'ebox.runnerd';
use constant REPORTERD_SERVICE   => 'zentyal.reporterd';
use constant COMPANY_KEY         => 'subscribedHostname';
use constant CRON_FILE           => '/etc/cron.d/zentyal-remoteservices';
use constant RELEASE_UPGRADE_MOTD => '/etc/update-motd.d/91-release-upgrade';
use constant REDIR_CONF_FILE     => EBox::Config::etc() . 'remoteservices_redirections.yaml';
use constant DEFAULT_REMOTE_SITE => 'remote.zentyal.com';

# OCS conf constants
use constant OCS_CONF_FILE       => '/etc/ocsinventory/ocsinventory-agent.cfg';
use constant OCS_CONF_MAS_FILE   => 'remoteservices/ocsinventory-agent.cfg.mas';
use constant OCS_CRON_FILE       => '/etc/cron.daily/ocsinventory-agent';
use constant OCS_CRON_MAS_FILE   => 'remoteservices/ocsinventory-agent.cron.mas';

my %i18nLevels = ( '-1' => __('Unknown'),
                   '0'  => __('Community'),
                   '5'  => __('Small Business'),
                   '6'  => __('Professional'),
                   '7'  => __('Business'),
                   '8'  => __('Enterprise Trial'),
                   '10' => __('Enterprise'),
                   '20' => __('Premium'));

# Group: Protected methods

# Constructor: _create
#
#        Create an event module
#
# Overrides:
#
#        <EBox::Module::Base::_create>
#
# Returns:
#
#        <EBox::RemoteServices> - the recently created module
#
sub _create
{
    my $class = shift;

    my $self = $class->SUPER::_create(name => 'remoteservices',
                                      printableName => __('Zentyal Remote Client'),
                                      @_);

    bless ($self, $class);

    return $self;
}

# Method: proxyDomain
#
#   Returns proxy's domain name or undef if service is disabled
#
sub proxyDomain
{
    my ($self) = @_;

    if ( $self->eBoxSubscribed() ) {
        return $self->_confKeys()->{realm};
    }
    return undef;
}

# Method: _setConf
#
#        Regenerate the configuration for the remote services module
#
# Overrides:
#
#       <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    $self->_setProxyRedirections();
    $self->_confSOAPService();
    if ($self->eBoxSubscribed()) {
        $self->_setUpAuditEnvironment();
        $self->_establishVPNConnection();
        $self->_vpnClientAdjustLocalAddress();
        $self->_reportAdminPort();
    }
    $self->_writeCronFile();
    $self->_setQAUpdates();
    $self->_setRemoteSupportAccessConf();
    $self->_setInventoryAgentConf();
    $self->_setNETRCFile();
    $self->_startupTasks();
    $self->_updateMotd();
}

# Method: initialSetup
#
#     Perform the required migrations
#
# Overrides:
#
#     <EBox::Module::Base::initialSetup>
#
sub initialSetup
{
    my ($self, $version) = @_;

    if (defined ($version)) {
        # Reload bundle without forcing
        $self->reloadBundle(0);
    }

    EBox::Sudo::root('chown -R ebox:adm ' . EBox::Config::conf() . 'remoteservices');

    unless (-e '/var/lib/zentyal/tmp/upgrade-from-CC') {
        $self->restartService();
    }
}

sub _setRemoteSupportAccessConf
{
    my ($self) = @_;

    my $supportAccess =
        $self->model('RemoteSupportAccess')->allowRemoteValue();
    my $fromAnyAddress =
        $self->model('RemoteSupportAccess')->fromAnyAddressValue();

    if ($supportAccess and (not $fromAnyAddress) and (not $self->eBoxSubscribed() )) {
        EBox::debug('Cannot restrict access for remote support if Zentyal server is not subscribed');
        return;
    }

    EBox::RemoteServices::SupportAccess->setEnabled($supportAccess, $fromAnyAddress);
    if ($self->eBoxSubscribed() and $self->hasBundle()) {
        my $conn = new EBox::RemoteServices::Connection();
        my $vpnClient = $conn->vpnClient();
        if ($vpnClient) {
            EBox::RemoteServices::SupportAccess->setClientRouteUp($supportAccess, $vpnClient);
        }
    }
    EBox::Sudo::root(EBox::Config::scripts() . 'sudoers-friendly');
}

sub _setInventoryAgentConf
{
    my ($self) = @_;

    my $toRemove = 0;
    if ( $self->inventoryEnabled() ) {
        my $cloud_domain = $self->cloudDomain();
        EBox::error('Cannot get Zentyal Remote domain name') unless $cloud_domain;

        # Check subscription level
        if ($cloud_domain and ($self->subscriptionLevel(1) > 0)) {
            my $cred = $self->cloudCredentials();

            # UUID Format for login: Hexadecimal without '0x'
            my $ug = new Data::UUID;
            my $bin_uuid = $ug->from_string($cred->{uuid});
            my $hex_uuid = $ug->to_hexstring($bin_uuid);
            my $user = substr($hex_uuid, 2);      # Remove the '0x'
            my $pass = $cred->{password};

            # OCS Server url
            my $ocs_server = 'https://inventory.' . $cloud_domain . '/ocsinventory';

            # Agent configuration
            my @params = (
                server    => $ocs_server,
                user      => $user,
                password  => $pass,
               );

            $self->writeConfFile(OCS_CONF_FILE, OCS_CONF_MAS_FILE, \@params);

            # Enable OCS agent periodic execution
            $self->writeConfFile(OCS_CRON_FILE,
                                 OCS_CRON_MAS_FILE,
                                 [], { 'mode' => '0755' } );
        } else {
            $toRemove = 1;
        }
    } else {
        $toRemove = 1;
    }

    if ( $toRemove and (-e OCS_CRON_FILE) ) {
        # Disable OCS agent periodic execution
        EBox::Sudo::root('rm -f ' . OCS_CRON_FILE);
    }
}

sub _writeCredentials   # ($fh, $host, $user, $pass)
{
    my ($fh, $host, $user, $pass) = @_;

    print $fh "machine $host\n";
    print $fh "login $user\n";
    print $fh "password $pass\n\n";
}

# Set up .netrc file in user's $HOME
sub _setNETRCFile
{
    my ($self) = @_;

    my $file = EBox::Config::home() . '/.netrc';

    if ($self->eBoxSubscribed()) {
        my $cred = EBox::RemoteServices::Cred->new();
        my $cloudDomain = $cred->cloudDomain();
        my $credentials  = $cred->cloudCredentials();

        my $fileHandle;
        open($fileHandle, '>', $file);
        chmod 0700, $fileHandle;

        # Conf backup
        _writeCredentials($fileHandle,
                          "confbackup.$cloudDomain",
                          $credentials->{uuid},
                          $credentials->{password});

        # Security updates

        # Password: UUID in hexadecimal format (without '0x')
        my $ug = new Data::UUID;
        my $bin_uuid = $ug->from_string($credentials->{uuid});
        my $hex_uuid = $ug->to_hexstring($bin_uuid);

        _writeCredentials($fileHandle,
                          "security-updates.$cloudDomain",
                          $cred->subscribedHostname(),
                          substr($hex_uuid, 2));

        close($fileHandle);
    } else {
        unlink($file);
    }
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
            'name'         => RUNNERD_SERVICE,
            'precondition' => \&runRunnerd,
        },
        {
            'name'         => REPORTERD_SERVICE,
            'precondition' => \&reportEnabled,
        },
       ];
}

# Method: isEnabled
#
#       Module is enabled only when the subscription is done
#
# Overrides:
#
#       <EBox::Module::Service::isEnabled>
#
sub isEnabled
{
    my ($self) = @_;
#    return  $self->eBoxSubscribed();
    return 1;
}

# Method: wizardPages
#
# Overrides:
#
#       <EBox::Module::Base::wizardPages>
#
sub wizardPages
{
    my ($self) = @_;

    return [] if EBox::Config::configkey('hide_subscription_wizard');

    return [{ page => '/RemoteServices/Wizard/Subscription', order => 10000 }];
}

# Method: eventDispatchers
#
# Overrides:
#
#      <EBox::Events::DispatcherProvider::eventDispatchers>
#
sub eventDispatchers
{
    return [ 'ControlCenter' ];
}

# Group: Public methods

# Method: addModuleStatus
#
# Overrides:
#
#       <EBox::Module::Service::addModuleStatus>
#
sub addModuleStatus
{
    my ($self, $section) = @_;

    my $subscriptionStatus = __('Not subscribed');
    if ( $self->eBoxSubscribed() ) {
        $subscriptionStatus = __('Subscribed');
    }

    $section->add(new EBox::Dashboard::ModuleStatus(
        module        => $self->name(),
        printableName => $self->printableName(),
        nobutton      => 1,
        statusStr     => $subscriptionStatus));
}

# Method: showModuleStatus
#
# Overrides:
#
#       <EBox::Module::Service::showModuleStatus>
#
sub showModuleStatus
{
    return 0;
}

# Method: menu
#
# Overrides:
#
#       <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder(name => 'RemoteServices',
                                        icon => 'register',
                                        text => __('Registration'),
                                        separator => 'Core',
                                        order => 105);

    $folder->add(new EBox::Menu::Item('url'  => 'RemoteServices/Composite/General',
                                      'text' => __('Server Registration'),
                                     ));

    $folder->add(new EBox::Menu::Item(
        'url'  => 'RemoteServices/Composite/Technical',
        'text' => __('Technical Support'),
       ));
    $folder->add(new EBox::Menu::Item(
        'url'  => 'RemoteServices/View/AdvancedSecurityUpdates',
        'text' => __('Security Updates'),
       ));
    $root->add($folder);

    if ($self->disasterRecoveryAvailable()) {
        my $system = new EBox::Menu::Folder(
            'name' => 'SysInfo',
            'text' => __('System'),
            'order' => 30
        );

        $system->add(new EBox::Menu::Item(
            'url' => 'SysInfo/DisasterRecovery',
            'separator' => 'Core',
            'order' => 45,
            'text' => __('Disaster Recovery')
        ));

        $root->add($system);
    }
}

# Method: widgets
#
# Overrides:
#
#    <EBox::Module::Base::widgets>
#
sub widgets
{
    my ($self) = @_;

    return {
        'ccConnection' => {
            'title'   => __('Your Zentyal Server Account'),
            'widget'  => \&_ccConnectionWidget,
            'order'  => 4,
            'default' => 1,
        }
       };

}

# Method: eBoxSubscribed
#
#        Test if current Zentyal is subscribed to remote services
#
# Returns:
#
#        true - if the current Zentyal is subscribed
#
#        false - otherwise
#
sub eBoxSubscribed
{
    my ($self) = @_;

    return $self->model('Subscription')->eBoxSubscribed();

}

# Method: unsubscribe
#
#        Delete every data related to the Zentyal subscription and stop any
#        related service associated with it
#
# Returns:
#
#        True  - if the Zentyal is subscribed and now it is not
#
#        False - if the Zentyal was not subscribed before
#
sub unsubscribe
{
    my ($self) = @_;

    return $self->model('Subscription')->unsubscribe();
}

# Method: eBoxCommonName
#
#        The common name to be used as unique which is subscribed by
#        this Zentyal. It has sense only when
#        <EBox::RemoteServices::eBoxSubscribed> returns true.
#
# Returns:
#
#        String - the subscribed Zentyal common name
#
#        undef - if <EBox::RemoteServices::eBoxSubscribed> returns
#        false
#
sub eBoxCommonName
{
    my ($self) = @_;

    if ( $self->eBoxSubscribed() ) {
        return $self->model('Subscription')->eboxCommonNameValue();
    } else {
        return undef;
    }

}

# Method: subscriberUsername
#
#        The subscriber's user name. It has sense only when
#        <EBox::RemoteServices::eBoxSubscribed> returns true.
#
# Returns:
#
#        String - the subscriber user name
#
#        undef - if <EBox::RemoteServices::eBoxSubscribed> returns
#        false
#
sub subscriberUsername
{
    my ($self) = @_;

    if ( $self->eBoxSubscribed() ) {
        return $self->model('Subscription')->usernameValue();
    } else {
        return undef;
    }

}

# Method: monitorGathererIPAddresses
#
#        Return the monitor gatherer IP adresses
#
# Returns:
#
#        array ref - the monitor gatherer IP addresses to send stats to
#
#                    empty array if it cannot gather the IP addresses properly
#
# Exceptions:
#
#        <EBox::Exceptions::External> - thrown if the host is not
#        subscribed to Zentyal Cloud
#
sub monitorGathererIPAddresses
{
    my ($self) = @_;

    unless ( $self->eBoxSubscribed() ) {
        throw EBox::Exceptions::External(
            __('The monitor gatherer IP addresses are only available if the host is subscribed to Zentyal Remote'));
    }

    my $monGatherers = [];

    if ( $self->monitorEnabled() ) {
        # If conf key says so, monitoring goes inside the VPN
        if (EBox::Config::boolean('monitoring_inside_vpn')) {
            try {
                $monGatherers = EBox::RemoteServices::Auth->new()->monitorGatherers();
            } catch (EBox::Exceptions::Base $e) {
            }
        } else {
            try {
                # TODO: Do not hardcode
                $monGatherers = ['mon.' . $self->cloudDomain()];
            } catch (EBox::Exceptions::External $e) {
            }
        }
    }
    return $monGatherers;
}

# Method: controlPanelURL
#
#        Return the control panel fully qualified URL to access
#        control panel
#
# Returns:
#
#        String - the control panel URL
#
# Exceptions:
#
#        <EBox::Exceptions::External> - thrown if the URL cannot be
#        found in configuration files
#
sub controlPanelURL
{
    my ($self) = @_;

    my $url = DEFAULT_REMOTE_SITE;
    try {
        my $cloudDomain = $self->cloudDomain('silent');
        if ($cloudDomain ne 'cloud.zentyal.com') {
            $url = "www.$cloudDomain";
        }
    } catch {
    }

    return "https://${url}/";
}

# Method: ifaceVPN
#
#        Return the virtual VPN interface for the secure connection
#        between this Zentyal and Zentyal Cloud
#
# Return:
#
#        String - the interface name
#
#        Undef  - If none has been defined yet
sub ifaceVPN
{
    my ($self) = @_;

    my $connection = new EBox::RemoteServices::Connection();
    my $vpnClient = $connection->vpnClient();
    if ($vpnClient) {
        return $vpnClient->iface();
    } else {
        # throw EBox::Exceptions::Internal('No VPN client created');
        return undef;
    }
}

# Method: vpnSettings
#
#        Return the virtual VPN settings for the secure connection
#        between this Zentyal and Zentyal Cloud
#
# Return:
#
#        hash ref - containing the following elements
#
#             ipAddr - String the VPN Server IP address
#             port   - Int the port to connect to
#             protocol - String the protocol associated to that port
#
sub vpnSettings
{
    my ($self) = @_;

    my $conn = new EBox::RemoteServices::Connection();
    my ($ipAddr, $port, $protocol) = @{$conn->vpnLocation()};

    return { ipAddr => $ipAddr,
             port => $port,
             protocol => $protocol };

}

# Method: isConnected
#
#         Check whether the server is connected to Zentyal Cloud or not
#
#         If the server is not subscribed, it returns false too
#
# Return:
#
#         Boolean - indicating the state
#
sub isConnected
{
    my ($self) = @_;

    return 0 unless $self->eBoxSubscribed();

    my $conn = new EBox::RemoteServices::Connection();
    return $conn->isConnected();
}

# Method: hasBundle
#
#    Return if the module has the load the bundle or not
#
#    This state happens when we have subscribed, but we don't have the
#    bundle yet
#
# Returns:
#
#    Boolean - whether the bundle has been loaded or not
#
sub hasBundle
{
    my ($self) = @_;

    return 0 unless $self->eBoxSubscribed();

    return ($self->st_get_bool('has_bundle'));
}

# Method: reloadBundle
#
#    Reload the bundle from Zentyal Cloud using the Web Service
#    to do so.
#
#    This method must be called only from post-installation script,
#    crontab or installation process.
#
# Parameters:
#
#    force - Boolean indicating to reload the bundle even if you think
#            you have the latest version *(Optional)* Default value: False
#
# Returns:
#
#    1 - if the reload was done successfully
#
#    2 - no reload is needed (force is false)
#
#    0 - when subscribed, but we cannot reach Zentyal Cloud
#
# Exceptions:
#
#    <EBox::Exceptions::External> - thrown if the Zentyal is not
#    subscribed
#
sub reloadBundle
{
    my ($self, $force) = @_;

    $force = 0 unless (defined($force));

    my $retVal = 1;
    try {
        if ( $self->eBoxSubscribed() ) {
            EBox::RemoteServices::Subscription::Check->new()->checkFromCloud();
            my $version       = $self->version();
            my $bundleVersion = $self->bundleVersion();
            my $bundleGetter  = new EBox::RemoteServices::Bundle();
            my $bundleContent = $bundleGetter->retrieveBundle($version, $bundleVersion, $force);
            if ( $bundleContent ) {
                my $params = EBox::RemoteServices::Subscription->extractBundle($self->eBoxCommonName(), $bundleContent);
                my $confKeys = EBox::Config::configKeysFromFile($params->{confFile});
                EBox::RemoteServices::Subscription->executeBundle($params, $confKeys);
                $retVal = 1;
            } else {
                $retVal = 2;
            }
        } else {
            throw EBox::Exceptions::External(__('Zentyal must be subscribed to reload the bundle'));
        }
    } catch (EBox::Exceptions::Internal $e) {
        $retVal = 0;
    } catch (EBox::RemoteServices::Exceptions::NotCapable $e) {
        print STDERR __x('Cannot reload the bundle: {reason}', reason => $e->text()) . "\n";
        # Send the event to ZC
        my $evt = new EBox::Event(message     => $e->text(),
                                  source      => 'not-capable',
                                  level       => 'fatal',
                                  dispatchTo  => [ 'ControlCenter' ]);
        my $evts = $self->global()->modInstance('events');
        $evts->sendEvent(event => $evt);
    }

    return $retVal;
}

# Method: bundleVersion
#
# Returns:
#
#      Int - the bundle version if Zentyal is subscribed and with the bundle
#
#      0 - otherwise
#
sub bundleVersion
{
    my ($self) = @_;
    if ( $self->eBoxSubscribed() ) {
        my $bundleVersion = $self->_confKeys()->{version};
        if (not defined $bundleVersion) {
            return 0;
        }
        return $bundleVersion;
    } else {
        return 0;
    }
}

# Method: subscriptionLevel
#
#      Get the subscription level
#
# Parameters:
#
#      force - Boolean check against server
#              *(Optional)* Default value: false
#
# Returns:
#
#      Int - the subscription level
#
#         -1 - no subscribed or impossible to know
#          0 - basic
#          5 - sb
#          8 - trial
#          10 - enterprise
#
sub subscriptionLevel
{
    my ($self, $force) = @_;

    $force = 0 unless defined($force);

    my $ret;
    try {
        $ret = $self->_getSubscriptionDetails($force)->{level};
    } catch {
        $ret = -1;
    }
    return $ret;
}

# Method: subscriptionCodename
#
#      Get the subscription codename
#
# Parameters:
#
#      force - Boolean check against server
#              *(Optional)* Default value: false
#
# Returns:
#
#      String - the subscription codename
#
#         '' - no subscribed or impossible to know
#         basic
#         professional
#         enterprise
#         trial
#
sub subscriptionCodename
{
    my ($self, $force) = @_;

    $force = 0 unless defined($force);

    my $ret;
    try {
        $ret = $self->_getSubscriptionDetails($force)->{codename};
    } catch {
        $ret = '';
    }
    return $ret;
}

# Method: technicalSupport
#
#      Get the level of technical support if any
#
# Parameters:
#
#      force - Boolean check against server
#              *(Optional)* Default value: false
#
# Returns:
#
#      An integer with the following possible values:
#
#         -2 : Unknown
#         -1 : no support
#          0 : Essential Support
#          1 : Standard Support
#          2 : Premium Support
#
sub technicalSupport
{
    my ($self, $force) = @_;

    $force = 0 unless defined($force);

    my $ret;
    try {
        $ret = $self->_getSubscriptionDetails($force)->{technical_support};
    } catch {
        $ret = -2;
    }
    return $ret;
}

# Method: renovationDate
#
#      Get the date when the subscription must be renewed
#
# Parameters:
#
#      force - Boolean check against server
#              *(Optional)* Default value: false
#
# Returns:
#
#      An integer with the following possible values:
#
#         -1 : Unknown
#          0 : Unlimited
#         >0 : Seconds since epoch when the subscription must be renewed
#
sub renovationDate
{
    my ($self, $force) = @_;

    $force = 0 unless defined($force);

    my $ret;
    try {
        $ret = $self->_getSubscriptionDetails($force)->{renovation_date};
    } catch {
        $ret = -1;
    }
    return $ret;
}

# Method: maxUsers
#
#   Return the max number of users the server can hold,
#   depending on the current server edition, 0 for unlimited
#
# Parameters:
#
#      force - Boolean check against server
#              *(Optional)* Default value: false
#
sub maxUsers
{
    my ($self, $force) = @_;

    # unlimited
    my $max_users = 0;

    if ($self->addOnAvailable('serverusers', $force)) {
        $max_users = $self->addOnDetails('serverusers', $force)->{max};
    }

    return $max_users;
}

# Method: maxCloudUsers
#
#   Return the max number of users available in Cloud (if enabled)
#   0 for unlimited or not enabled
#
# Parameters:
#
#      force - Boolean check against server
#              *(Optional)* Default value: false
#
sub maxCloudUsers
{
    my ($self, $force) = @_;
    if ($self->usersSyncAvailable($force)) {
        return $self->addOnDetails('cloudusers', $force)->{max_users};
    }
    return 0;
}

# Method: usersSyncAvailable
#
#   Returns 1 if users syncrhonization is available
#
# Parameters:
#
#      force - Boolean check against server
#              *(Optional)* Default value: false
#
sub usersSyncAvailable
{
    my ($self, $force) = @_;

    return $self->addOnAvailable('cloudusers', $force);
}

# Method: filesSyncAvailable
#
#   Returns 1 if file synchronisation is available
#
sub filesSyncAvailable
{
    my ($self, $force) = @_;

    return $self->addOnAvailable('cloudfiles', $force);
}

# Method: securityUpdatesAddOn
#
#      Get if server has security updates add-on
#
# Parameters:
#
#      force - Boolean check against server
#              *(Optional)* Default value: false
#
# Returns:
#
#      Boolean - indicating if it has security updates add-on or not
#
sub securityUpdatesAddOn
{
    my ($self, $force) = @_;

    $force = 0 unless defined($force);

    my $ret;
    try {
        $ret = $self->_getSubscriptionDetails($force)->{security_updates};
    } catch {
        $ret = 0;
    }
    return $ret;
}

# Method: disasterRecoveryAvailable
#
#      Get whether the server has disaster recovery available
#
# Parameters:
#
#      force - Boolean check against server
#              *(Optional)* Default value: false
#
# Returns:
#
#      Boolean - indicating whether the server has disaster recovery
#                available or not
#
sub disasterRecoveryAvailable
{
    my ($self, $force) = @_;

    my $ret = $self->addOnDetails('disaster-recovery', $force);
    return ( scalar(keys(%{$ret})) > 0);
}

# Method: addOnAvailable
#
#      Return 1 if addon is available, undef if not
#
# Parameters:
#
#      addOn - String the add-on name to get the details from
#
#      force - Boolean check against the cloud
#              *(Optional)* Default value: false
#
sub addOnAvailable
{
    my ($self, $addOn, $force) = @_;

    $force = 0 unless defined($force);

    my $ret = undef;
    try {
        my $subsDetails = $self->_getSubscriptionDetails($force);
        if ( not exists $subsDetails->{cap} ) {
            $subsDetails = $self->_getSubscriptionDetails('force'); # Forcing
        }
        $ret = (exists $subsDetails->{cap}->{$addOn});
    } catch {
        $ret = undef;
    }
    return $ret;
}

# Method: addOnDetails
#
#      Get the add-on details for a given add-on
#
# Parameters:
#
#      addOn - String the add-on name to get the details from
#
#      force - Boolean check against the cloud
#              *(Optional)* Default value: false
#
# Returns:
#
#      Hash ref - indicating the add-on details
#                 Empty hash if no add-on is there for this server
#
sub addOnDetails
{
    my ($self, $addOn, $force) = @_;

    $force = 0 unless defined($force);

    my $ret = {};
    try {
        my $subsDetails = $self->_getSubscriptionDetails($force);
        if ( not exists $subsDetails->{cap} ) {
            $subsDetails = $self->_getSubscriptionDetails('force'); # Forcing
        }
        if (exists $subsDetails->{cap}->{$addOn}) {
            my $detail = $self->_getCapabilityDetail($addOn, $force);
            $ret = $detail;
        }
    } catch {
        $ret = {};
    }
    return $ret;
}

# Method: backupCredentials
#
#     This method is *DEPRECATED*
#
#     Get the backup credentials if the server is connected to Zentyal
#     Cloud. If not connected, then the method requires three arguments
#     to get the information from the public Web Service
#
#     There is a cache to store the value that it may be overriden by
#     setting the force parameter
#
# Parameters:
#
#       force - Boolean indicating if we have to search for the
#               credentials to the Zentyal Cloud or not
#
#       username - String the customer's name or email address
#
#       password - String the customer's password
#
#       commonName - String the Zentyal server name
#
#       - Named parameters
#
# Returns:
#
#     hash ref - containing the following key-value pairs
#
#           username - String the user name
#           password - String the password for that user in that server
#           server   - String the backup server host name
#           quota    - Int the allowed quota
#
sub backupCredentials
{
    my ($self, %args) = @_;

    # Disable DR for now
    throw EBox::Exceptions::DeprecatedMethod();
}

# Method: serverList
#
#    Give the Zentyal server list
#
# Parameters:
#
#    user - String the user name
#
#    password - String the password
#
#    - Named parameters
#
# Returns:
#
#      Array ref - the Zentyal server common names
#
sub serverList
{
    my ($self, %args) = @_;

    my $connector = new EBox::RemoteServices::Subscription(%args);

    return $connector->serversList();
}

# Method: queryInternalNS
#
#    Query the internal nameserver
#
# Parameters:
#
#    hostname - String the host to ask for
#
#    method - String to determine which answer to retrieve.
#             Possible values:
#                 - random: select one IP address randomly (Default)
#                 - all : return all IP addresses
#
# Returns:
#
#    empty string - if there is no answer
#
#    String - the IP address if random or first method is selected
#
#    array ref - the IP addresses if all method is selected
#
# Exceptions:
#
#    <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#    argument is missing
#
#    <EBox::Exceptions::Internal> - thrown if the host is not
#    connected to the cloud
#
sub queryInternalNS
{
    my ($self, $hostname, $method) = @_;

    defined($hostname) or throw EBox::Exceptions::MissingArgument('hostname');

    throw EBox::Exceptions::Internal('No connected') unless ( $self->isConnected() );

    $method = 'random' unless (defined($method));

    my $ns = $self->_confKeys()->{dnsServer};
    my $resolver = new Net::DNS::Resolver(nameservers => [ $ns ],
                                          defnames    => 0,
                                          udp_timeout => 15);

    my $response = $resolver->query($hostname);

    return '' unless (defined($response));

    my @addresses = map { $_->address() } (grep { $_->type() eq 'A' } $response->answer());

    given ( $method ) {
        when ( 'random' ) {
            my $n = int(rand(scalar(@addresses)));
            return $addresses[$n];
        }
        when ( 'all' ) {
            return \@addresses;
        }
        default {
            throw EBox::Exceptions::Internal("Invalid method $method");
        }
    }
}

# Method: confKey
#
#     Return a configuration key from the subscription bundle if available
#
# Parameters:
#
#     key - String the configuration key
#
# Returns:
#
#     String - the configuration key value if any
#
#     undef - if there is not bundle or there is not such key
#
sub confKey
{
    my ($self, $key) = @_;

    my $keys = $self->_confKeys();
    if ( defined($keys) ) {
        return $keys->{$key};
    }
    return undef;
}

# Method: setSecurityUpdatesLastTime
#
#      Set the security updates has been applied
#
# Parameters:
#
#      time - Int seconds since epoch
#             *(Optional)* Default value: time()
#
sub setSecurityUpdatesLastTime
{
    my ($self, $time) = @_;

    $time = time() unless (defined($time));

    my $state = $self->get_state();
    $state->{security_updates}->{last_update} = $time;
    $self->set_state($state);
}

# Method: latestSecurityUpdates
#
#      Get the last time when the security updates were applied
#
# Returns:
#
#      String - the date in RFC 2822 format
#
#      'unknown' - if the date is not available
#
sub latestSecurityUpdates
{
    my ($self) = @_;

    my $state = $self->get_state();
    if (exists $state->{security_updates}->{last_update}) {
        my $curr = $state->{security_updates}->{last_update};
        return POSIX::strftime("%c", localtime($curr));
    } else {
        return 'unknown';
    }
}

# Method: latestRemoteConfBackup
#
#      Get the last time when a configuration backup (manual or
#      automatic) has been done
#
# Returns:
#
#      String - the date in RFC 2822 format
#
#      'unknown' - if the date is not available
#
sub latestRemoteConfBackup
{
    my ($self) = @_;

    my $bakService = new EBox::RemoteServices::Backup();
    return $bakService->latestRemoteConfBackup();
}

# Method: reportAdminPort
#
#     Report to Zentyal Cloud for a new TCP port for the Zentyal
#     server admin interface.
#
#     It will do so only if the server is connected to Zentyal Cloud
#
# Parameters:
#
#     port - Int the new TCP port
#
# Exceptions:
#
#     <EBox::Exceptions::InvalidData> - if the given port is not a
#     valid port
#
sub reportAdminPort
{
    my ($self, $port) = @_;

    EBox::Validate::checkPort($port, "$port is not a valid port");

    my $state = $self->get_state();

    if ($self->eBoxSubscribed()) {
        # Check for a change in admin port
        if ((not $state->{'admin_port'}) or ($state->{'admin_port'} != $port)) {
            my $adminPortRS = new EBox::RemoteServices::AdminPort();
            $adminPortRS->setAdminPort($port);
            $state->{admin_port} = $port;
            $self->set_state($state);
        }
    }
}

# Method: DDNSServerIP
#
#     Get the DynDNS Server IP address if the host is connected
#
# Returns:
#
#     String - the IP address to use. Empty string if this cannot be got
#
sub DDNSServerIP
{
    my ($self) = @_;

    my $ret = "";

    if ( $self->eBoxSubscribed() ) {
        my $hostname = $self->_confKeys()->{dynamicDnsServer};

        if ( $hostname ) {
            try {
                $ret = $self->queryInternalNS($hostname, 'random');
            } catch { };
        }
    }
    return $ret;

}

# Method: dynamicHostname
#
#    Get the Dynamic Hostname for the DynDNS service if the server is
#    connected
#
# Returns:
#
#    String - the FQDN for the dynamic DNS hostname. Empty string if
#             the server is not subscribed
#
sub dynamicHostname
{
    my ($self) = @_;

    my $ret = "";

    if ( $self->eBoxSubscribed() ) {
        my $domain = $self->dynamicDomain();
        $ret = $self->eBoxCommonName() . '.' . $domain;
    }
    return $ret;
}

# Method: i18nServerEdition
#
#     Get the server edition printable name
#
# Parameters:
#
#     level - Int the level for taking the edition
#             *(Optional)* Default value: $self->subscriptionLevel()
#
# Returns:
#
#     String - the printable edition
#
sub i18nServerEdition
{
    my ($self, $level) = @_;

    $level = $self->subscriptionLevel() unless (defined($level));

    if ( exists($i18nLevels{$level}) ) {
        return $i18nLevels{$level};
    } else {
        return __('Unknown');
    }
}

# Method: subscriptionDir
#
#      The subscription directory path
#
# Parameters:
#
#      force - Boolean indicating to return value stored in the model
#              even if the server is not subscribed
#
# Returns:
#
#      String - the path where the bundle is untar'ed and credentials
#      are stored
#
sub subscriptionDir
{
    my ($self, $force) = @_;
    my $cn;
    $cn = $self->eBoxCommonName();
    if ( not defined($cn) and $force ) {
        $cn = $self->model('Subscription')->eboxCommonNameValue();
    }

    return  SUBS_DIR . $cn;
}

# Method: reportEnabled
#
#     Get if the given server has the report feature enabled
#
# Returns:
#
#     Boolean
#
sub reportEnabled
{
    my ($self) = @_;

    return ($self->eBoxSubscribed() and $self->subscriptionLevel() > 0);
}

# Method: monitorEnabled
#
#     Get if the given server has the monitor feature enabled
#
# Returns:
#
#     Boolean
#
sub monitorEnabled
{
    my ($self) = @_;

    return $self->reportEnabled();
}

# Method: inventoryEnabled
#
#     Get if the given server has the inventory feature enabled
#
# Returns:
#
#     Boolean
#
sub inventoryEnabled
{
    my ($self) = @_;

    return $self->reportEnabled();
}

# Method: runRunnerd
#
#     Get if runnerd daemon should be run.
#
#     By default, run if the server is registered. If not, then this
#     depends on the value set by <ensureRunnerdRunning> method
#
# Returns:
#
#     Boolean
#
sub runRunnerd
{
    my ($self) = @_;

    return 1 if ($self->eBoxSubscribed());
    return $self->get_bool('runnerd_always_running');
}

# Method: ensureRunnerdRunning
#
#     Ensure runnerd is running even when the server is not
#     registered.
#
#     Save changes is required to start/stop runnerd daemon.
#
# Parameters:
#
#     run - Boolean indicating if runnerd is meant to be run or not
#
sub ensureRunnerdRunning
{
    my ($self, $run) = @_;

    $run = 0 unless (defined($run));
    $self->set_bool('runnerd_always_running', $run);
}

# Method: pushAdMessage
#
#    Push an ad message to be shown in the dashboard
#
# Parameters:
#
#    key - String the unique key for this ad message
#          It will be used to pop it out in <popAdMessage>
#    msg - String the message itself
#
sub pushAdMessage
{
    my ($self, $key, $msg) = @_;

    my $state = $self->get_state();
    $state->{ad_messages}->{$key} = $msg;
    $self->set_state($state);
}

# Method: popAdMessage
#
#    Pop out an ad message. Opposite to <pushAdMessage>
#
# Parameters:
#
#    key - String the unique key for this ad message
#          It should used to push out in <popAdMessage>
#
# Returns:
#
#    undef - if there were no message with that key
#
#    msg - String the deleted message
#
sub popAdMessage
{
    my ($self, $key) = @_;

    my $state = $self->get_state();
    return undef unless(exists($state->{ad_messages}));
    my $deletedMsg = delete $state->{ad_messages}->{$key};
    $self->set_state($state);
    return $deletedMsg;
}

# Method: adMessages
#
#    Get the adMessages set by <pushAdMessage>
#
# Returns:
#
#    Hash ref - containing the following keys:
#
#       name - 'remoteservices'
#       text - the text itself
#
sub adMessages
{
    my ($self, $plain) = @_;

    my $adMessages = $self->get_state()->{ad_messages};
    my $rsMsg = "";
    foreach my $adMsgKey (keys(%{$adMessages})) {
        $rsMsg .= $adMessages->{$adMsgKey} . ' ';
    }
    return { name => 'remoteservices', text => $rsMsg };
}

# Method: checkAdMessages
#
#    Check if we have to remove any ad message
#
sub checkAdMessages
{
    my ($self) = @_;

    if ($self->eBoxSubscribed()) {
        # Launch our checker to see if the max_users message disappear
        my $checker = new EBox::RemoteServices::Subscription::Check();
        my $state = $self->get_state();
        my $maxUsers = $self->addOnDetails('serverusers');
        my $det = $state->{subscription};
        $det->{capabilities}->{serverusers} = $maxUsers;
        $checker->check($det);
    }
}

# Group: Private methods

# Configure the SOAP server
#
# if subscribed and has bundle
# 1. Write soap-loc.mas template
# 2. Write the SSLCACertificatePath directory
# 3. Add include in zentyal-apache configuration
# elsif not subscribed
# 1. Remove SSLCACertificatePath directory
# 2. Remove include in zentyal-webadmin configuration
#
sub _confSOAPService
{
    my ($self) = @_;

    my $confFile = SERV_DIR . 'soap-loc.conf';
    my $confSSLFile = SERV_DIR . 'soap-loc-ssl.conf';
    my $webAdminMod = EBox::Global->modInstance('webadmin');
    if ($self->eBoxSubscribed()) {
        if ($self->hasBundle()) {
            my @tmplParams = (
                (soapHandler      => WS_DISPATCHER),
                (caDomain         => $self->_confKeys()->{caDomain}),
                (allowedClientCNs => $self->_allowedClientCNRegexp()),
            );
            EBox::Module::Base::writeConfFileNoCheck($confFile, 'remoteservices/soap-loc.conf.mas', \@tmplParams);
            EBox::Module::Base::writeConfFileNoCheck($confSSLFile, 'remoteservices/soap-loc-ssl.conf.mas', \@tmplParams);

            $webAdminMod->addApacheInclude($confFile);
            $webAdminMod->addNginxInclude($confSSLFile);
            $webAdminMod->addCA($self->_caCertPath());
        }
    } else {
        # Do nothing if CA or include are already removed
        try {
            $webAdminMod->removeApacheInclude($confFile);
            $webAdminMod->removeNginxInclude($confSSLFile);
            $webAdminMod->removeCA($self->_caCertPath('force'));
        } catch (EBox::Exceptions::Internal $e) {
        }
    }
    # We have to save web admin changes to load the CA certificates file for SSL validation.
    $webAdminMod->save();
}

# Configure Apache Proxy redirections server
#
# if subscribed and has bundle and remoteservices_redirections.conf is written
# 1. Write proxy-redirections.conf.mas template
# 2. Add include in zentyal-apache configuration
# elsif not subscribed
# 1. Remove include in zentyal-apache configuration
#
sub _setProxyRedirections
{
    my ($self) = @_;

    my $confFile = SERV_DIR . 'proxy-redirections.conf';
    my $webadminMod = EBox::Global->modInstance('webadmin');
    if ($self->eBoxSubscribed() and $self->hasBundle() and (-r REDIR_CONF_FILE)) {
        try {
            my $redirConf = YAML::XS::LoadFile(REDIR_CONF_FILE);
            my @tmplParams = (
                redirections => $redirConf,
               );
            EBox::Module::Base::writeConfFileNoCheck(
                $confFile,
                'remoteservices/proxy-redirections.conf.mas',
                \@tmplParams);
            $webadminMod->addApacheInclude($confFile);
        } catch ($e) {
            # Not proper YAML file
            EBox::error($e);
        };
    } else {
        # Do nothing if include is already removed
        try {
            unlink($confFile) if (-f $confFile);
            $webadminMod->removeApacheInclude($confFile);
        } catch (EBox::Exceptions::Internal $e) {
        }
    }
    # We have to save Apache changes:
    # From GUI, it is assumed that it is done at the end of the process
    # From CLI, we have to call it manually in some way. TODO: Find it!
    # $webadminMod->save();
}

# Assure the VPN connection with our VPN servers is established
sub _establishVPNConnection
{
    my ($self) = @_;

    if ( $self->_VPNEnabled() ) {
        try {
            my $authConnection = new EBox::RemoteServices::Connection();
            $authConnection->create();
            $authConnection->connect();
        } catch (EBox::Exceptions::External $e) {
            EBox::error("Cannot contact to Zentyal Remote: $e");
        }
    }
}

# Perform the tasks done just after subscribing
sub _startupTasks
{
    my ($self) = @_;

    my $execFilePath = EBox::Config::etc() . 'post-save/at-start-up-rs';
    if ( $self->st_get_bool('just_subscribed') ) {
        # Set to reload bundle after 1min after saving changes in
        # /etc/zentyal/post-save
        my $fhEtc = new File::Temp(DIR => EBox::Config::tmp());
        $fhEtc->unlink_on_destroy(0);
        print $fhEtc "#!/bin/bash\n";
        print $fhEtc "at -f '" . EBox::Config::scripts('remoteservices') . 'startup-tasks' . "' now+1min\n";
        close($fhEtc);
        chmod( 0755, $fhEtc->filename() );
        EBox::Sudo::root('mv ' . $fhEtc->filename() . " $execFilePath");

        $self->st_set_bool('just_subscribed', 0);
    } else {
        # Cleaning up the reload bundle at command, if any
        EBox::Sudo::root("rm -f '$execFilePath'");
    }
}

# Write the cron file
sub _writeCronFile
{
    my ($self) = @_;

    if ($self->eBoxSubscribed()) {
        my $hours = $self->get_list('rand_hours');
        unless ( @{$hours} > 0 ) {
            # Set the random times when scripts must ask for information
            my @randHours = map
              { my $r = int(rand(9)) - 2; $r += 24 if ($r < 0); $r }
                0 .. 10;
            my @randMins  = map { int(rand(60)) } 0 .. 10;
            $self->set_list('rand_hours', 'int', \@randHours);
            $self->set_list('rand_mins' , 'int',  \@randMins);
            $hours = \@randHours;
        }

        my $mins = $self->get_list('rand_mins');

        my @tmplParams = (
            ( hours => $hours), (mins => $mins)
           );

        EBox::Module::Base::writeConfFileNoCheck(
            CRON_FILE,
            'remoteservices/zentyal-remoteservices.cron.mas',
            \@tmplParams);
    } elsif (-e CRON_FILE) {
        EBox::Sudo::root("rm -f '" . CRON_FILE . "'");
    }
}

sub _setUpAuditEnvironment
{
    my $johnDir = EBox::RemoteServices::Configuration::JohnHomeDirPath();
    unless ( -d $johnDir ) {
        mkdir($johnDir);
    }
}

# Return the allowed client CNs regexp
sub _allowedClientCNRegexp
{
    my ($self) = @_;

    my $mmProxy  = $self->_confKeys()->{managementProxy};
    my $wwwProxy = $self->_confKeys()->{wwwServiceProxy};
    my ($mmPrefix, $mmRem) = split(/\./, $mmProxy, 2);
    my ($wwwPrefix, $wwwRem) = split(/\./, $wwwProxy, 2);
    my $nums = '[0-9]+';
    return "^(${mmPrefix}$nums.${mmRem}|${wwwPrefix}$nums.${wwwRem})\$";
}

# Return the given configuration file from the control center
sub _confKeys
{
    my ($self) = @_;

    unless ( defined($self->{confFile}) ) {
        my $confDir = $self->subscriptionDir();
        my @confFiles = <$confDir/*.conf>;
        if (@confFiles == 0) {
            return { }; # There may be no bundle
        }
        $self->{confFile} = $confFiles[0];
    }
    unless ( defined($self->{confKeys}) ) {
        $self->{confKeys} = EBox::Config::configKeysFromFile($self->{confFile});
    }
    return $self->{confKeys};
}

# Return the CA cert path
sub _caCertPath
{
    my ($self, $force) = @_;

    return $self->subscriptionDir($force) . '/cacert.pem';
}

# Return the Zentyal Cloud connection widget to be shown in the dashboard
sub _ccConnectionWidget
{
    my ($self, $widget) = @_;

    my $section = new EBox::Dashboard::Section('cloud_section');
    $widget->add($section);

    my ($serverName, $fqdn, $connValue, $connValueType, $subsLevelValue, $DRValue) =
      ( __('None'), '', '', 'info', '', __('Disabled'));

    my $ASUValue = __x('Disabled - {oh}Enable{ch}',
                       oh => '<a href="/RemoteServices/View/AdvancedSecurityUpdates">',
                       ch => '</a>');
    my $supportValue = __x('Disabled - {oh}Enable{ch}',
                           oh => '<a href="/RemoteServices/Composite/Technical">',
                           ch => '</a>');

    if ( $self->eBoxSubscribed() ) {
        $connValue     = __('Connected');
        $connValueType = 'info';
        if ( $self->_VPNRequired() ) {
            if ( not $self->hasBundle() ) {
                $connValue     = __('In process');
                $connValueType = 'info';
            } elsif ( not $self->isConnected() ) {
                $connValue = __x('Not connected. {oh}Check VPN connection{ch} and logs in {path}',
                                  oh   => '<a href="/RemoteServices/View/VPNConnectivityCheck">',
                                  ch   => '</a>',
                                  path => '/var/log/openvpn/');
                $connValueType = 'error';
            }
        } # else. No VPN required, then always connected

        $serverName = $self->eBoxCommonName();
        my $gl  = EBox::Global->getInstance(1);
        my $net = $gl->modInstance('network');
        if ( $net->can('DDNSUsingCloud') and $net->DDNSUsingCloud() ) {
            $fqdn = $self->dynamicHostname();
        }

        $subsLevelValue = $self->i18nServerEdition();

        my %i18nSupport = ( '-2' => __('Unknown'),
                            '-1' => $supportValue,
                            '0'  => __('Standard 2 days'),
                            '1'  => __('Standard 1 day'),
                            '2'  => __('Standard 4 hours'),
                            '3'  => __('Premium'));
        $supportValue = $i18nSupport{$self->technicalSupport()};

        if ( $self->securityUpdatesAddOn() ) {
            $ASUValue = __x('Running');
            my $date = $self->latestSecurityUpdates();
            if ( $date ne 'unknown' ) {
                $ASUValue .= ' ' . __x('- Last update: {date}', date => $date);
            }
        }

        $DRValue = __x('Configuration backup enabled');
        my $date;
        try {
            $date = $self->latestRemoteConfBackup();
        } catch {
            $date = 'unknown';
        }
        if ( $date ne 'unknown' ) {
            $DRValue .= ' ' . __x('- Latest conf backup: {date}', date => $date);
        }

    } else {
        $connValue      = __sx('Not registered - {oh}Register now!{ch}',
                               oh => '<a href="/RemoteServices/Composite/General">',
                               ch => '</a>');
        $subsLevelValue = __sx('None - {oh}Register for Free!{ch}',
                               oh => '<a href="/RemoteServices/Composite/General">',
                               ch => '</a>');
    }

    $section->add(new EBox::Dashboard::Value(__('Server name'), $serverName));
    $section->add(new EBox::Dashboard::Value(__('Connection status'),
                                             $connValue, $connValueType));
    if ( $fqdn ) {
        $section->add(new EBox::Dashboard::Value(__('External server name'),
                                                 $fqdn));
    }
    $section->add(new EBox::Dashboard::Value(__('Server edition'),
                                             $subsLevelValue));
    $section->add(new EBox::Dashboard::Value(__('Technical support'),
                                             $supportValue));
    $section->add(new EBox::Dashboard::Value(__s('Security Updates'),
                                             $ASUValue));
    $section->add(new EBox::Dashboard::Value(__s('Configuration backup'),
                                             $DRValue));
}

# Set the subscription details
# If not subscribed, an exception is raised
sub _getSubscriptionDetails
{
    my ($self, $force) = @_;

    my $state = $self->get_state();

    if ($force or (not exists $state->{subscription}->{level})) {
        unless ($self->eBoxSubscribed()) {
            throw EBox::Exceptions::Internal('Not subscribed', silent => 1);
        }
        my $cap = new EBox::RemoteServices::Capabilities();
        my $details;
        try {
            $details = $cap->subscriptionDetails();
        } catch (EBox::Exceptions::Internal $e) {
            # Impossible to know the new state
            # Get cached data
            unless (exists $state->{subscription}->{level}) {
                $e->throw();
            }
        }

        if ( defined($details) ) {
            $state->{subscription} = {
                level             => $details->{level},
                codename          => $details->{codename},
                technical_support => $details->{technical_support},
                renovation_date   => $details->{renovation_date},
                security_updates  => $details->{security_updates},
                # disaster_recovery => $details->{disaster_recovery},
                # sb_comm_add_on    => $details->{sb_comm_add_on},
            };
            my $capList;
            try {
                $capList = $cap->list();
                my %capList = map { $_ => 1 } @{$capList};
                $state->{subscription}->{cap} = \%capList;
            } catch (EBox::Exceptions::Internal $e) {
            }
            $self->set_state($state);
        }
    }

    return $state->{subscription};
}

# Get and cache the cap details
sub _getCapabilityDetail
{
    my ($self, $capName, $force) = @_;

    my $state = $self->get_state();
    if ( $force or (not exists $state->{subscription}->{cap_detail}->{$capName}) ) {
        my $cap = new EBox::RemoteServices::Capabilities();
        my $detail;
        try {
            $detail = $cap->detail($capName);
        } catch (EBox::Exceptions::Internal $e) {
            # Impossible to know the current state
            # Get cached data if any, if there is not, then raise the exception
            unless (exists $state->{subscription}->{cap_detail}->{$capName}) {
                $e->throw();
            }
        }
        $state->{subscription}->{cap_detail}->{$capName} = $detail;
        $self->set_state($state);
    }
    return $state->{subscription}->{cap_detail}->{$capName};
}

# Get the latest backup date
sub _latestBackup
{
    my ($self) = @_;

    my $latest = __('No data backup has been done yet');
    my $gl = EBox::Global->getInstance();
    if ($gl->modExists('ebackup')) {
        my $ebackup = EBox::Global->modInstance('ebackup');
        my $latestDate = $ebackup->lastBackupDate();
        if ($latestDate) {
            $latest = $latestDate;
        }
    } else {
        # Use the conf backup data
        $latest = $self->latestRemoteConfBackup();
    }

    return $latest;
}

# Report the Zentyal server TCP admin port to Zentyal Cloud
sub _reportAdminPort
{
    my ($self) = @_;

    my $gl = EBox::Global->getInstance(1);
    my $webAdminMod = $gl->modInstance('webadmin');

    $self->reportAdminPort($webAdminMod->port());
}

# Method: extraSudoerUsers
#
#  Returns:
#    list with usernames to add to the system's sudoers users
sub extraSudoerUsers
{
    my ($self) = @_;
    my @users;
    my $supportAccess =
        $self->model('RemoteSupportAccess')->allowRemoteValue();
    if ($supportAccess) {
        push @users,
            EBox::RemoteServices::SupportAccess->remoteAccessUser;
    }

    return @users;
}

# Get the path for subscription data in the backup
sub _backupSubsDataTarFileName
{
    my ($self, $dir) = @_;
    return "$dir/subscription.tar.gz";
}

# Method: dumpConfig
#
#     Override to store the subscription conf path
#
# Overrides:
#
#     <EBox::Module::Base::dumpConfig>
#
sub dumpConfig
{
    my ($self, $dir) = @_;

    if (not $self->eBoxSubscribed()) {
        # no subscription to back up
        return;
    }

    # tar with subscription files directory
    my $tarPath = $self->_backupSubsDataTarFileName($dir);
    my $subscriptionDir =  SUBS_DIR;
    my $tarCmd = "tar cf '$tarPath' '$subscriptionDir'";
    EBox::Sudo::root($tarCmd);
}

# Method: restoreConfig
#
#     Override to restore the subscription conf path and state
#
# Overrides:
#
#     <EBox::Module::Base::restoreConfig>
#
sub restoreConfig
{
    my ($self, $dir) = @_;

    $self->clearCache();

    # restore state conf
    $self->_load_state_from_file($dir);

    my $tarPath = $self->_backupSubsDataTarFileName($dir);
    # Parse backed up server-info.json to know if we are restoring a
    # first installed server or a disaster recovery one. In those
    # cases, the server password has been modified and the backed one
    # is not valid anymore
    my ($backupSubscribed, $excludeServerInfo) = (EBox::Sudo::fileTest('-r', $tarPath), 0);
    if ($self->eBoxSubscribed()) {
        try {
            # For hackers!
            EBox::Sudo::root("tar xf '$tarPath' --no-anchored --strip-components=7 -C /tmp server-info.json");
            my $backupedServerInfo = decode_json(File::Slurp::read_file('/tmp/server-info.json'));
            # If matches, then skip to restore the server-info.json
            $excludeServerInfo = ($backupedServerInfo->{uuid} eq new EBox::RemoteServices::Cred()->subscribedUUID());
        } catch ($e) {
            EBox::error("Error restoring subscription. Reverting back to unsubscribed status");
            EBox::error($e);
            $self->clearCache();
            $self->st_set_bool('subscribed', 0);
            $backupSubscribed = 0;
        }
        EBox::Sudo::root('rm -f /tmp/server-info.json');
    }

    if ($backupSubscribed) {
        # Restore subscription files and ownership
        my $subscriptionDir = SUBS_DIR;
        try {
            my $tarCmd = "tar --extract --file '$tarPath' --directory /";
            $tarCmd .= " --exclude=server-info.json" if ($excludeServerInfo);
            my @cmds = ($tarCmd,
                        "chown ebox.adm '$subscriptionDir'",
                        "chown -R ebox.ebox $subscriptionDir/*");
            EBox::Sudo::root(@cmds);
        } catch ($e) {
            EBox::error("Error restoring subscription. Reverting back to unsubscribed status");
            EBox::error($e);
            $self->clearCache();
            $self->st_set_bool('subscribed', 0);
        }
    }

    # Mark as changed to make all things work again
    $self->setAsChanged();
}

# Method: clearCache
#
#     Remove cached information stored in module state
#
sub clearCache
{
    my ($self) = @_;

    my $state = $self->get_state();
    my @cacheDirs = qw(subscription disaster_recovery);
    foreach my $dir (@cacheDirs) {
        delete $state->{$dir};
    }
    $self->set_state($state);
}

sub staticIfaceAddressChangedDone
{
    my ($self) = @_;
    $self->setAsChanged();
}

sub ifaceMethodChangeDone
{
    my ($self) = @_;
    $self->setAsChanged();
}

sub freeIface
{
    my ($self) = @_;
    $self->setAsChanged();
}

sub freeViface
{
    my ($self) = @_;
    $self->setAsChanged();
}

sub _vpnClientAdjustLocalAddress
{
    my ($self) = @_;

    return unless $self->_VPNEnabled();

    my $conn = new EBox::RemoteServices::Connection();
    my $vpnClient = $conn->vpnClient();
    if ( $vpnClient ) {
        $conn->vpnClientAdjustLocalAddress($vpnClient);
    }
}

# This method determines if the VPN must be enabled or not
# Requisites:
#   - Be subscribed
#   - Have the cert bundle
#   - Allow remote access support or be entitled to remote access
#
sub _VPNEnabled
{
    my ($self, $force) = @_;

    if ( (not $force) and exists($self->{'_vpnEnabled'}) ) {
        return $self->{'_vpnEnabled'};
    }

    my $vpnEnabled = ($self->eBoxSubscribed() and $self->hasBundle());
    if ( $vpnEnabled ) {
        $vpnEnabled = $self->_VPNRequired('force');
    }
    $self->{'_vpnEnabled'} = $vpnEnabled;
    return $vpnEnabled;
}

# This method determines if the VPN is required. That is:
#   - Allow remote access support or be entitled to remote access
sub _VPNRequired
{
    my ($self, $force) = @_;

    if ( (not $force) and exists($self->{'_vpnRequired'}) ) {
        return $self->{'_vpnRequired'};
    }

    my $vpnRequired = $self->model('RemoteSupportAccess')->allowRemoteValue();
    unless ( $vpnRequired ) {
        $vpnRequired = ($self->subscriptionLevel('force') > 0);
    }

    $self->{'_vpnRequired'} = $vpnRequired;
    return $vpnRequired;
}

sub firewallHelper
{
    my ($self) = @_;

    my $enabled = ($self->eBoxSubscribed() and $self->hasBundle());
    if (not $enabled) {
        return undef;
    }

    my $remoteSupport =  $self->model('RemoteSupportAccess')->allowRemoteValue();

    return EBox::RemoteServices::FirewallHelper->new(
        remoteSupport => $remoteSupport,
        vpnInterface => $self->ifaceVPN(),
        sshRedirect => EBox::RemoteServices::SupportAccess->sshRedirect(),
       );
}

# Method: REST
#
#   Return the REST client ready to query remote services
#
sub REST
{
    my ($self) = @_;

    unless ($self->{rest}) {
        my $cred = new EBox::RemoteServices::Cred();
        $self->{rest} = $cred->RESTClient();
    }

    return $self->{rest};
}

# Method: subscribedHostname
#
#        Return the hostname within the Zentyal Cloud if
#        the host is subscribed to it
#
# Returns:
#
#        String - the subscribed hostname
#
# Exceptions:
#
#        <EBox::Exceptions::External> - thrown if the host is not
#        subscribed to Zentyal Cloud
#
sub subscribedHostname
{
    my ($self) = @_;

    unless ( $self->eBoxSubscribed() ) {
        throw EBox::Exceptions::External(
            __('The subscribed hostname is only available if the host is subscribed to Zentyal Remote')
           );
    }

    unless ( defined($self->{subscribedHostname}) ) {
        $self->{subscribedHostname} = EBox::RemoteServices::Cred->new()->subscribedHostname();
    }
    return $self->{subscribedHostname};
}

# Method: subscribedUUID
#
#        Return the server UUID if this is subscribed to Zentyal Cloud
#
# Returns:
#
#        String - the UUID
#
# Exceptions:
#
#        <EBox::Exceptions::External> - thrown if the host is not
#        subscribed to Zentyal Cloud
#
sub subscribedUUID
{
    my ($self) = @_;

    unless ( $self->eBoxSubscribed() ) {
        throw EBox::Exceptions::External(
            __('The UUID is only available if the host is subscribed to Zentyal Remote')
           );
    }

    unless ( defined($self->{subscribedUUID}) ) {
        $self->{subscribedUUID} = EBox::RemoteServices::Cred->new()->subscribedUUID();
    }
    return $self->{subscribedUUID};
}

# Method: cloudDomain
#
#        Return the Zentyal Cloud Domain if the server is subscribed
#
# Parameters:
#
#        silent - String if the host is not registered, throw a silent
#                 exception
#
# Returns:
#
#        String - the Zentyal Cloud Domain
#
# Exceptions:
#
#        <EBox::Exceptions::External> - thrown if the host is not
#        subscribed to Zentyal Cloud
#
sub cloudDomain
{
    my ($self, $silent) = @_;

    unless ( $self->eBoxSubscribed() ) {
        throw EBox::Exceptions::External(
            __('The Zentyal Remote Domain is only available if the host is subscribed'),
            silent => $silent
           );
    }

    unless ( defined($self->{cloudDomain}) ) {
        # we need to check credError beause this method is used for referer check
        my $credError = EBox::RemoteServices::Cred->credentialsFileError($self->eBoxCommonName());
        if ($credError) {
            return undef;
        }
        $self->{cloudDomain} = EBox::RemoteServices::Cred->new()->cloudDomain();
    }
    return $self->{cloudDomain};
}

# Method: dynamicDomain
#
#        Return the Zentyal Cloud Dynamic Domain if the server is
#        subscribed
#
# Returns:
#
#        String - the Zentyal Cloud Dynamic Domain
#
# Exceptions:
#
#        <EBox::Exceptions::External> - thrown if the host is not
#        subscribed to Zentyal Cloud
#
sub dynamicDomain
{
    my ($self) = @_;

    unless ( $self->eBoxSubscribed() ) {
        throw EBox::Exceptions::External(
            __('The Zentyal Remote Dynamic Domain is only available if the host is subscribed')
           );
    }

    unless ( defined($self->{dynamicDomain}) ) {
        $self->{dynamicDomain} = EBox::RemoteServices::Cred->new()->dynamicDomain();
    }
    return $self->{dynamicDomain};
}

# Method: cloudCredentials
#
#        Return the Zentyal Cloud Credentials if the server is subscribed
#
# Returns:
#
#        Hash ref - 'uuid' and 'password'
#
# Exceptions:
#
#        <EBox::Exceptions::External> - thrown if the host is not
#        subscribed to Zentyal Cloud
#
sub cloudCredentials
{
    my ($self) = @_;

    unless ( $self->eBoxSubscribed() ) {
        throw EBox::Exceptions::External(
            __('The Zentyal Remote credentials are only available if the host is subscribed')
           );
    }
    unless ( defined($self->{cloudCredentials}) ) {
        $self->{cloudCredentials} = EBox::RemoteServices::Cred->new()->cloudCredentials();
    }
    return $self->{cloudCredentials};

}

# Method: _setQAUpdates
#
#       Turn the QA Updates ON or OFF depending on the subscription level
#
sub _setQAUpdates
{
    EBox::RemoteServices::QAUpdates::set();

}

# Update MOTD scripts depending on the subscription status
sub _updateMotd
{
    my ($self) = @_;

    my @tmplParams = (
         (subscribed => $self->eBoxSubscribed())
        );
    if ($self->eBoxSubscribed() ) {
        push(@tmplParams, (editionMsg => __sx('This is a Zentyal Server {edition} edition.',
                                                edition => $self->i18nServerEdition())));
    }
    EBox::Module::Base::writeConfFileNoCheck(
        RELEASE_UPGRADE_MOTD,
        'remoteservices/release-upgrade-motd.mas',
        \@tmplParams, { mode => '0755' });

}

1;
