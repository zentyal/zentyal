# Copyright (C) 2008-2012 eBox Technologies S.L.
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

package EBox::RemoteServices;

# Class: EBox::RemoteServices
#
#      RemoteServices module to handle everything related to the remote
#      services offered
#
use base qw(EBox::Module::Service
            EBox::NetworkObserver
            EBox::Events::DispatcherProvider
            EBox::Desktop::ServiceProvider
            EBox::FirewallObserver);

use strict;
use warnings;

use feature qw(switch);

use Date::Calc;
use EBox::Config;
use EBox::Dashboard::ModuleStatus;
use EBox::Dashboard::Section;
use EBox::Dashboard::Value;
use EBox::DBEngineFactory;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::NotConnected;
use EBox::Gettext;
use EBox::Global;
use EBox::Service;
use EBox::RemoteServices::Audit::Password;
use EBox::RemoteServices::AdminPort;
use EBox::RemoteServices::Backup;
use EBox::RemoteServices::Bundle;
use EBox::RemoteServices::Capabilities;
use EBox::RemoteServices::Connection;
use EBox::RemoteServices::Configuration;
use EBox::RemoteServices::Cred;
use EBox::RemoteServices::Desktop::Subscription;
use EBox::RemoteServices::DisasterRecovery;
use EBox::RemoteServices::DisasterRecoveryProxy;
use EBox::RemoteServices::Subscription;
use EBox::RemoteServices::SupportAccess;
use EBox::RemoteServices::FirewallHelper;
use EBox::RemoteServices::RESTClient;
use EBox::RemoteServices::QAUpdates;
use EBox::Sudo;
use EBox::Util::Version;
use EBox::Validate;
use Error qw(:try);
use Net::DNS;
use File::Slurp;
use JSON::XS;
use POSIX;

# Constants
use constant SERV_DIR            => EBox::Config::conf() . 'remoteservices/';
use constant CA_DIR              => EBox::Config::conf() . 'ssl-ca/';
use constant SUBS_DIR            => SERV_DIR . 'subscription/';
use constant WS_DISPATCHER       => __PACKAGE__ . '::WSDispatcher';
use constant RUNNERD_SERVICE     => 'ebox.runnerd';
use constant SITE_HOST_KEY       => 'siteHost';
use constant COMPANY_KEY         => 'subscribedHostname';
use constant CRON_FILE           => '/etc/cron.d/zentyal-remoteservices';

my %i18nLevels = ( '-1' => __('Unknown'),
                   '0'  => __('Community'),
                   '1'  => __('Professional'),
                   '2'  => __('Enterprise'),
                   '5'  => __('Small Business'),
                   '10' => __('Enterprise'));

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
                                      printableName => __n('Zentyal Cloud Client'),
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

    $self->_confSOAPService();
    if ($self->eBoxSubscribed()) {
        $self->_establishVPNConnection();
        $self->_vpnClientAdjustLocalAddress();
        $self->_writeCronFile();
        $self->_startupTasks();
        $self->_reportAdminPort();
# TODO: QAUpdates
    }

    $self->_setRemoteSupportAccessConf();
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

    $self->SUPER::initialSetup($version);

    unless (-e '/var/lib/zentyal/tmp/upgrade-from-CC') {
        $self->restartService();
    }

    if (defined($version) and EBox::Util::Version::compare($version, '2.3') < 0) {
        # Perform the migration to 2.3
        $self->_migrateTo30();
    }
}

sub _setRemoteSupportAccessConf
{
    my ($self) = @_;

    my $supportAccess =
        $self->model('RemoteSupportAccess')->allowRemoteValue();
    my $fromAnyAddress =
        $self->model('RemoteSupportAccess')->fromAnyAddressValue();


    if ($supportAccess and (not $fromAnyAddress) and (not  $self->eBoxSubscribed() )) {
        EBox::error('Cannot restrict access for remote support if Zentyal server is not subscribed');
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
            'precondition' => \&eBoxSubscribed,
        }
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
                                        text => __('Subscription'),
                                        separator => 'Core',
                                        order => 105);

    $folder->add(new EBox::Menu::Item('url'  => 'RemoteServices/Composite/General',
                                      'text' => __('Server Subscription'),
                                     ));

    $folder->add(new EBox::Menu::Item(
        'url'  => 'RemoteServices/Composite/Technical',
        'text' => __('Technical Support'),
       ));
    $folder->add(new EBox::Menu::Item(
        'url'  => 'RemoteServices/View/AdvancedSecurityUpdates',
        'text' => __('Security Updates'),
       ));
    $folder->add(new EBox::Menu::Item(
        'url'  => 'RemoteServices/View/DisasterRecovery',
        'text' => __('Disaster Recovery'),
       ));
    $root->add($folder);
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
        'cc_connection' => {
            'title'   => __('Zentyal Cloud Services'),
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
            __('The subscribed hostname is only available if the host is subscribed to Zentyal Cloud')
           );
    }

    my $hostName = EBox::RemoteServices::Cred->new()->subscribedHostname();
    return $hostName;
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
            __('The monitor gatherer IP addresses are only available if the host is subscribed to Zentyal Cloud'));
    }

    # FIXME: Use monitor outside VPN
    my $monGatherers = [];
    try {
        $monGatherers = EBox::RemoteServices::Auth->new()->monitorGatherers();
    } catch EBox::Exceptions::Base with {
        ;
    };
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
    my $url= 'cloud.zentyal.com';
    try {
        $url = EBox::RemoteServices::Auth->new()->valueFromBundle(SITE_HOST_KEY);
    } otherwise {};

    return "https://${url}/"
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
sub ifaceVPN
{
    my ($self) = @_;

    my $connection = new EBox::RemoteServices::Connection();
    my $vpnClient = $connection->vpnClient();
    if ($vpnClient) {
        return $vpnClient->iface();
    } else {
        throw EBox::Exceptions::Internal('No VPN client created');
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
            EBox::RemoteServices::Subscription::Check->new()->checkFromCloud($self->eBoxCommonName());
            my $new = $self->hasBundle();
            my $version       = $self->version();
            my $bundleVersion = $self->bundleVersion();
            my $bundleGetter  = new EBox::RemoteServices::Bundle();
            my $bundleContent = $bundleGetter->retrieveBundle($version, $bundleVersion, $force);
            if ( $bundleContent ) {
                my $params = EBox::RemoteServices::Subscription->extractBundle($self->eBoxCommonName(), $bundleContent);
                my $confKeys = EBox::Config::configKeysFromFile($params->{confFile});
                EBox::RemoteServices::Subscription->executeBundle($params, $confKeys, $new);
                $retVal = 1;
            } else {
                $retVal = 2;
            }
        } else {
            throw EBox::Exceptions::External(__('Zentyal must be subscribed to reload the bundle'));
        }
    } catch EBox::Exceptions::Internal with {
        $retVal = 0;
    };
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
#          1 - professional
#          2 - enterprise
#
sub subscriptionLevel
{
    my ($self, $force) = @_;

    $force = 0 unless defined($force);

    my $ret;
    try {
        $ret = $self->_getSubscriptionDetails($force)->{level};
    } otherwise {
        $ret = -1;
    };
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
#
sub subscriptionCodename
{
    my ($self, $force) = @_;

    $force = 0 unless defined($force);

    my $ret;
    try {
        $ret = $self->_getSubscriptionDetails($force)->{codename};
    } otherwise {
        $ret = '';
    };
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
    } otherwise {
        $ret = -2;
    };
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
    } otherwise {
        $ret = -1;
    };
    return $ret;
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
    } otherwise {
        $ret = 0;
    };
    return $ret;
}

# Method: disasterRecoveryAddOn
#
#      Get whether the company has disaster recovery add-on or not
#
# Parameters:
#
#      force - Boolean check against server
#              *(Optional)* Default value: false
#
# Returns:
#
#      Boolean - indicating whether the company has disaster recovery
#      add-on or not
#
# Exceptions:
#
#      <EBox::Exceptions::NotConnected> - thrown if the server cannot
#      connect to Zentyal Cloud to know the answer
#
sub disasterRecoveryAddOn
{
    my ($self, $force) = @_;

    $force = 0 unless defined($force);

    my $ret;
    try {
        $ret = $self->_getSubscriptionDetails($force)->{disaster_recovery};
    } otherwise {
        throw EBox::Exceptions::NotConnected();
    };
    return $ret;
}

# Method: backupCredentials
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

    my $state = $self->get_state();

    if ($args{force} or not exists $state->{disaster_recovery}->{username}) {
        my $cred;
        if ( $self->isConnected() ) {
            my $disRecAgent = new EBox::RemoteServices::DisasterRecovery();
            $cred = $disRecAgent->credentials();
        } else {
            unless (defined($args{username})) {
                throw EBox::Exceptions::MissingArgument('username');
            }
            unless (defined($args{password})) {
                throw EBox::Exceptions::MissingArgument('password');
            }
            unless (defined($args{commonName})) {
                throw EBox::Exceptions::MissingArgument('commonName');
            }
            my $disRecAgent = new EBox::RemoteServices::DisasterRecoveryProxy(
                user => $args{username}, password => $args{password}
               );
            $cred = $disRecAgent->credentials(commonName => $args{commonName});
        }
        if (defined($cred->{username})) {
            $state->{disaster_recovery}->{username} = $cred->{username};
            $state->{disaster_recovery}->{password} = $cred->{password};
            $state->{disaster_recovery}->{server} = $cred->{server};
            $state->{disaster_recovery}->{quota} = $cred->{quota};
            $self->set_state($state);
        } else {
            $state->{disaster_recovery} = {};
            $self->set_state($state);
            return {};
        }
    }

    return $state->{disaster_recovery};
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

# Method: lastGeneratedReport
#
#      Get the last generated report date if any
#
# Returns:
#
#      Int - seconds since epoch when last report was generated
#
#      undef - if there is no info about it
#
sub lastGeneratedReport
{
    my ($self) = @_;

    my $state = $self->get_state();
    if (exists $state->{subscription}->{report_generated_at}) {
        return $state->{subscription}->{report_generated_at};
    } else {
        return undef;
    }
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
    if (exists $state->{subscription}->{securityUpdates_last_update}) {
        my $curr = $state->{subscription}->{securityUpdates_last_update};
        return POSIX::strftime("%c", localtime($curr));
    } else {
        return 'unknown';
    }
}

# Method: latestSecurityUpdates
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

    my $latest = 'unknown';
    try {
        my $bakService = new EBox::RemoteServices::Backup();
        my $bakList    = $bakService->listRemoteBackups();
        my @sortedBakList = sort { $b->{sortableDate} <=> $a->{sortableDate} } values %{$bakList};
        if ( @sortedBakList > 0 ) {
            $latest = $sortedBakList[0]->{Date};
        }
    } otherwise { };

    return $latest;
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
            } otherwise { };
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
        my $domain = $self->_confKeys()->{dynamicDomain};
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
# Returns:
#
#      String - the path where the bundle is untar'ed and credentials
#      are stored
#
sub subscriptionDir
{
    my ($self) = @_;
    my $cn = $self->eBoxCommonName();
    # check if cn is udnef, commented bz iam not sure how it may affect _confKeys
#     if (not defined $cn) {
#         return undef;
#     }

    return  SUBS_DIR . $cn;
}

# Group: Public methods related to reporting

# Method: logReportInfo
#
# Overrides:
#
#     <EBox::Module::Base::logReportInfo>
#
sub logReportInfo
{
    my $db = EBox::DBEngineFactory::DBEngine();
    my $ret = $db->query('SELECT date FROM remoteservices_passwd_report '
                         . 'ORDER BY date DESC LIMIT 1');

    if ( defined($ret->[0]) and defined($ret->[0]->{date}) ) {
        my ($year, $month, $day) = $ret->[0]->{date} =~ m:([0-9]+)-([0-9]+)-([0-9]+):g;
        if ( Date::Calc::Delta_Days($year, $month, $day,
                                    Date::Calc::Today()) < 7 ) {
            # Do nothing every week
            return [];
        }
    }


    my $weakPasswdUsers = EBox::RemoteServices::Audit::Password::reportUserCheck();

    unless (defined($weakPasswdUsers)) {
        # This happens when the audit is being done. Wait for next day to report
        return [];
    }

    my @data = ();
    foreach my $user ( @{$weakPasswdUsers} ) {
        my $entry = {};
        $entry->{table}  = 'remoteservices_passwd_report';
        $entry->{values} = {};
        $entry->{values}->{username} = $user->{username};
        $entry->{values}->{level} = $user->{level};
        $entry->{values}->{source} = $user->{from};
        my @time = localtime(time());
        $entry->{values}->{date} = ($time[5] + 1900) . '-' . ($time[4] + 1) . "-$time[3]";
        push(@data, $entry);
    }
    # Store the current number of users
    my $nUsers = EBox::RemoteServices::Audit::Password::nUsers();
    push(@data, { table  => 'remoteservices_passwd_users',
                  values => { nusers => $nUsers }});

    return \@data;
}

# Method: consolidateReportInfoQueries
#
# Overrides:
#
#     <EBox::Module::Base::consolidateReportInfoQueries>
#
sub consolidateReportInfoQueries
{
    return [
        {
            target_table => 'remoteservices_passwd_users_report',
            query        => {
                select => 'nusers',
                from   => 'remoteservices_passwd_users',
               }
           }
       ];
}

# Method: report
#
# Overrides:
#
#   <EBox::Module::Base::report>
sub report
{
    my ($self, $beg, $end, $options) = @_;

    my $report = {};

    $report->{weak_password_number} = $self->runMonthlyQuery(
        $beg, $end,
        {
            select => 'COUNT(DISTINCT username) AS weak_passwords',
            from   => 'remoteservices_passwd_report',
            where  => "level = 'weak'",
            group  => 'level',
        },
      );
    my $averageQuery = $self->runMonthlyQuery(
        $beg, $end,
        {
            select => 'COUNT(DISTINCT username) AS average_passwords',
            from   => 'remoteservices_passwd_report',
            where  => "level = 'average'",
            group  => 'level',
        },
      );

    my $nUsersQuery = $self->runMonthlyQuery(
        $beg, $end,
        {
            select => 'nusers',
            from   => 'remoteservices_passwd_users_report',
           },
       );

    # Return if there is no users (first consolidation)
    return {} unless (defined($nUsersQuery->{nusers}));

    unless (defined( $averageQuery->{average_passwords} )) {
        $averageQuery->{average_passwords} = [];
        push(@{$averageQuery->{average_passwords}}, 0) foreach (1 .. @{$nUsersQuery->{nusers}});
    }

    unless (defined( $report->{weak_password_number}->{weak_passwords} )) {
        $report->{weak_password_number}->{weak_passwords} = [];
        push(@{$report->{weak_password_number}->{weak_passwords}}, 0)
          foreach (1 .. @{$nUsersQuery->{nusers}});
    }


    # Perform the union manually
    $report->{weak_password_number}->{nusers} = $nUsersQuery->{nusers};
    $report->{weak_password_number}->{average_passwords} = $averageQuery->{average_passwords};

    # Calculate the percentages on my own
    my @percentages;
    for (my $i=0; $i < scalar(@{$report->{weak_password_number}->{nusers}}); $i++) {
        my $nUsers = $report->{weak_password_number}->{nusers}->[$i];
        my $weakUsers = $report->{weak_password_number}->{weak_passwords}->[$i];
        if ( $nUsers == 0 ) {
            push(@percentages, 0);
        } else {
            my $percentage = 100*($weakUsers/$nUsers);
            push(@percentages, sprintf('%.2f', $percentage));
        }
    }
    $report->{weak_password_number}->{percentage} = \@percentages;

    $report->{weak_password_users} = $self->runQuery(
        $beg, $end,
        {
            select => 'DISTINCT username, level, source',
            from   => 'remoteservices_passwd_report',
        },
       );


    if (defined($report->{weak_password_users})) {
        # Get additional data to report
        my (@fullNames, @emails);
        for (my $i=0; $i < scalar(@{$report->{weak_password_users}->{username}}); $i++) {
            my $username = $report->{weak_password_users}->{username}->[$i];
            my $additionalInfo = EBox::RemoteServices::Audit::Password::additionalInfo($username);
            push(@fullNames, $additionalInfo->{fullname});
            push(@emails, $additionalInfo->{email});
        }
        $report->{weak_password_users}->{fullname} = \@fullNames;
        $report->{weak_password_users}->{email} = \@emails;
    }

    return $report;
}


# Group: Private methods

# Configure the SOAP server
#
# if subscribed
# 1. Write soap-loc.mas template
# 2. Write the SSLCACertificatePath directory
# 3. Add include in ebox-apache configuration
# else
# 1. Remove SSLCACertificatePath directory
# 2. Remove include in ebox-apache configuration
#
sub _confSOAPService
{
    my ($self) = @_;

    my $confFile = SERV_DIR . 'soap-loc.conf';
    my $apacheMod = EBox::Global->modInstance('apache');
    if ($self->eBoxSubscribed()) {
        if ( $self->hasBundle() ) {
            my @tmplParams = (
                (soapHandler      => WS_DISPATCHER),
                (caDomain         => $self->_confKeys()->{caDomain}),
                (allowedClientCNs => $self->_allowedClientCNRegexp()),
               );
            EBox::Module::Base::writeConfFileNoCheck(
                $confFile,
                'remoteservices/soap-loc.mas',
                \@tmplParams);

            $apacheMod->addInclude($confFile);
            $apacheMod->addCA($self->_caCertPath());
        }
    } else {
        try {
            $apacheMod->removeInclude($confFile);
            $apacheMod->removeCA($self->_caCertPath());
        } catch EBox::Exceptions::Internal with {
            # Do nothing if it's already remove
            ;
        };
    }
    # We have to save Apache changes:
    # From GUI, it is assumed that it is done at the end of the process
    # From CLI, we have to call it manually in some way. TODO: Find it!
    # $apacheMod->save();
    EBox::Global->modChange('apache');
}

# Assure the VPN connection with our VPN servers is established
sub _establishVPNConnection
{
    my ($self) = @_;

    if ( $self->eBoxSubscribed() and $self->hasBundle() ) {
        try {
            my $authConnection = new EBox::RemoteServices::Connection();
            $authConnection->create();
            $authConnection->connect();
        } catch EBox::Exceptions::External with {
            my ($exc) = @_;
            EBox::error("Cannot contact to Zentyal Cloud: $exc");
        };
    }
}

# Perform the tasks done just after subscribing
sub _startupTasks
{
    my ($self) = @_;

    if ( $self->st_get_bool('just_subscribed') ) {
        # Get the cron jobs after subscribing on the background
        system(EBox::Config::scripts('remoteservices') . 'get-cronjobs &');
        # Set the subscription level
        system(EBox::Config::scripts('remoteservices') . 'subs-level &');
        $self->st_set_bool('just_subscribed', 0);
    }
}

# Write the cron file
sub _writeCronFile
{
    my ($self) = @_;

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
        'remoteservices/ebox-remoteservices.cron.mas',
        \@tmplParams);
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
    my ($self) = @_;

    return $self->subscriptionDir() . '/cacert.pem';

}

# Return the Zentyal Cloud connection widget to be shown in the dashboard
sub _ccConnectionWidget
{
    my ($self, $widget) = @_;

    my $section = new EBox::Dashboard::Section('cloud_section');
    $widget->add($section);

    my ($serverName, $fqdn, $connValue, $connValueType, $subsLevelValue, $DRValue) =
      ( __('None'), '', '', 'info', '', '');

    my $ASUValue = __x('Disabled - {oh}Enable{ch}',
                       oh => '<a href="/RemoteServices/View/AdvancedSecurityUpdates">',
                       ch => '</a>');
    my $supportValue = __x('Disabled - {oh}Enable{ch}',
                           oh => '<a href="/RemoteServices/Composite/Technical">',
                           ch => '</a>');

    if ( $self->eBoxSubscribed() ) {
        $connValue = __x('Not connected. {oh}Check VPN connection{ch} and logs in {path}',
                         oh   => '<a href="/RemoteServices/View/VPNConnectivityCheck">',
                         ch   => '</a>',
                         path => '/var/log/openvpn/');
        $connValueType = 'error';
        if ( not $self->hasBundle() ) {
            $connValue     = __('In process');
            $connValueType = 'info';
        } elsif ( $self->isConnected() ) {
            $connValue     = __('Connected');
            $connValueType = 'info';
        }

        $serverName = $self->eBoxCommonName();
        my $gl  = EBox::Global->getInstance(1);
        my $net = $gl->modInstance('network');
        if ( $net->can('DDNSUsingCloud') and $net->DDNSUsingCloud() ) {
            $fqdn = $self->dynamicHostname();
        }

        $subsLevelValue = $self->i18nServerEdition();

        my %i18nSupport = ( '-2' => __('Unknown'),
                            '-1' => $supportValue,
                            '0'  => __('Essential'),
                            '1'  => __('Standard'),
                            '2'  => __('Premium'));
        $supportValue = $i18nSupport{$self->technicalSupport()};

        if ( $self->securityUpdatesAddOn() ) {
            $ASUValue = __x('Running');
            my $date = $self->latestSecurityUpdates();
            if ( $date ne 'unknown' ) {
                $ASUValue .= ' ' . __x('- Last update: {date}', date => $date);
            }
        }

        my $drOn = 0;
        try {
            $drOn = $self->disasterRecoveryAddOn();
        } catch EBox::Exceptions::NotConnected with { };

        if ( $drOn ) {
            $DRValue = __x('Enabled');
            my $date = $self->_latestBackup();
            if ( $date ne 'unknown' ) {
                $DRValue .= ' ' . __x('- Latest backup: {date}', date => $date);
            }
        } else {
            $DRValue = __x('Configuration backup enabled');
            my $date = $self->latestRemoteConfBackup();
            if ( $date ne 'unknown' ) {
                $DRValue .= ' ' . __x('- Latest conf backup: {date}', date => $date);
            }
        }

    } else {
        $connValue      = __sx('Not subscribed - {oh}Subscribe now!{ch}',
                               oh => '<a href="/RemoteServices/Composite/General">',
                               ch => '</a>');
        $subsLevelValue = __sx('None - {oh}Get Free Basic Subscription!{ch}',
                               oh => '<a href="/RemoteServices/Composite/General">',
                               ch => '</a>');
        $DRValue        = __sx('Disabled - {oh}Enable{ch}',
                               oh => '<a href="/RemoteServices/View/DisasterRecovery">',
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
    $section->add(new EBox::Dashboard::Value(__s('Disaster Recovery'),
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
            use Devel::StackTrace;
            my $t = new Devel::StackTrace();
            EBox::error($t->as_string());
            throw EBox::Exceptions::Internal('Not subscribed');
        }
        my $cap = new EBox::RemoteServices::Capabilities();
        my $details = $cap->subscriptionDetails();

        $state->{subscription} = {
            level => $details->{level},
            codename => $details->{codename},
            technical_support => $details->{technical_support},
            renovation_date => $details->{renovation_date},
            security_updates => $details->{security_updates},
            disaster_recovery => $details->{disaster_recovery}
        };
        $self->set_state($state);
    }

    return $state->{subscription};
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
    my $apache = $gl->modInstance('apache');

    $self->reportAdminPort($apache->port());
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

sub _backupSubscritionConf
{
    my ($self, $dir) = @_;
    return "$dir/subscription.conf";
}

sub _backupSubscritionTar
{
    my ($self, $dir) = @_;
    return "$dir/subscription.tar.gz";
}

sub dumpConfig
{
    my ($self, $dir) = @_;

    if (not $self->eBoxSubscribed()) {
        # no subscription to backup
        return;
    }

    # file with subscription and cache conf parameters
    my $subscriptionConfFile = $self->_backupSubscritionConf($dir);
    my $stringConf = encode_json($self->get_state());
    File::Slurp::write_file($subscriptionConfFile, $stringConf);

    # tar with subscription files directory
    my $tarPath = $self->_backupSubscritionTar($dir);
    my $subscriptionDir =  SUBS_DIR;
    my $tarCmd = 'tar  cf ' . $tarPath . ' ' . $subscriptionDir;
    EBox::Sudo::root($tarCmd);
}

sub restoreConfig
{
    my ($self, $dir) = @_;

    $self->clearCache();

    my $subscriptionConf = $self->_backupSubscritionConf($dir);
    if (not -r $subscriptionConf) {
        # no subscribed
        $self->st_set_bool('subscribed', 0);
        return;
    }

    # restore state conf
    my $state = decode_json(File::Slurp::read_file($subscriptionConf));
    $self->set_state($state);

    # restore subscription files and ownerhsip
    my $subscriptionDir = SUBS_DIR;
    try {
        my $tarPath = $self->_backupSubscritionTar($dir);
        my $tarCmd = 'tar x --file ' . $tarPath . ' -C /';
        EBox::Sudo::root($tarCmd);
        EBox::Sudo::root("chown ebox.adm '$subscriptionDir'");
        EBox::Sudo::root("chown -R ebox.ebox $subscriptionDir/*");
    } otherwise {
        my ($ex) = shift;
        EBox::error("Error restoring subscription. Reverting back to unsubscribed status");
        $self->clearCache();
        $self->st_set_bool('subscribed', 0);
    };
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
    if ((not $self->eBoxSubscribed()) or (not $self->hasBundle())) {
        return;
    }

    my $conn = new EBox::RemoteServices::Connection();
    my $vpnClient = $conn->vpnClient();
    if ( $vpnClient ) {
        $conn->vpnClientAdjustLocalAddress($vpnClient);
    }
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
        $self->{rest} = new EBox::RemoteServices::RESTClient();
    }

    return $self->{rest};
}

# Migration to 3.0
#
#  * Migrate current subscription data in state to new structure
#  * Rename VPN client
#  * Get credentials
#
sub _migrateTo30
{
    my ($self) = @_;

    # Drop old VPN client
    # Create a new one
    # Get credentials again
}


# Method: desktopActions
#
#   Return an array ref with the exposed methods
#
# Returns:
#
#   array ref - Containing the exposed actions
#
# Overrides:
#
#   <EBox::Desktop::ServiceProvider::desktopActions>
#
sub desktopActions
{
    return {
        'subscribe' => \&EBox::RemoteServices::Desktop::Subscription::subscribe,
    };
}

1;
