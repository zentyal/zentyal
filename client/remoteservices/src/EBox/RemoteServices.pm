# Copyright (C) 2008-2010 eBox Technologies S.L.
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
            EBox::Model::ModelProvider
            EBox::Model::CompositeProvider
           );

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
use EBox::Gettext;
use EBox::Global;
use EBox::Service;
use EBox::RemoteServices::Audit::Password;
use EBox::RemoteServices::Backup;
use EBox::RemoteServices::Bundle;
use EBox::RemoteServices::Capabilities;
use EBox::RemoteServices::Configuration;
use EBox::RemoteServices::DisasterRecovery;
use EBox::RemoteServices::DisasterRecoveryProxy;
use EBox::RemoteServices::Subscription;
use EBox::RemoteServices::SupportAccess;
use EBox::Sudo;
use Error qw(:try);
use Net::DNS;
use File::Slurp;

# Constants
use constant SERV_DIR            => EBox::Config::conf() . 'remoteservices/';
use constant CA_DIR              => EBox::Config::conf() . 'ssl-ca/';
use constant SUBS_DIR            => SERV_DIR . 'subscription/';
use constant WS_DISPATCHER       => __PACKAGE__ . '::WSDispatcher';
use constant RUNNERD_SERVICE     => 'ebox.runnerd';
use constant SITE_HOST_KEY       => 'siteHost';
use constant COMPANY_KEY         => 'subscribedHostname';
use constant CRON_FILE           => '/etc/cron.d/ebox-remoteservices';

# Group: Protected methods

# Constructor: _create
#
#        Create an event module
#
# Overrides:
#
#        <EBox::GConfModule::_create>
#
# Returns:
#
#        <EBox::Events> - the recently created module
#
sub _create
{

    my $class = shift;

    my $self = $class->SUPER::_create( name => 'remoteservices',
                                       domain => 'ebox-remoteservices',
                                       printableName => __n('Zentyal Cloud Client'),
                                       @_
                                      );

    bless ($self, $class);

    return $self;

}

# Method: domain
#
# Overrides:
#
#        <EBox::Module::domain>
#
sub domain
{
    return 'ebox-remoteservices';
}

sub restartService
{
    my $self = shift;
    $self->clearCache();
    return $self->SUPER::restartService(@_);
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

    if ($self->eBoxSubscribed()) {
        $self->_confSOAPService();
        $self->_establishVPNConnection();
        $self->_writeCronFile();
        $self->_startupTasks();
    }

    $self->_setRemoteSupportAccessConf();
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
    EBox::Sudo::root('/usr/share/ebox/ebox-sudoers-friendly');
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
    $root->add(new EBox::Menu::Item('url'  => 'RemoteServices/Composite/General',
                                    'name' => 'Subscription',
                                    'text' => __('Subscription'),
                                    'order' => 105,
                                   )
              );

    my $remoteSupportItem = new EBox::Menu::Item(
              'url'  => 'RemoteServices/View/RemoteSupportAccess',
              'name' => 'RemoteSupportAccess',
              'text' => __('Remote Support Access'),
                                                );
    my $folder = new EBox::Menu::Folder('name' => 'EBox',
                                        'text' => __('System'));

    $folder->add($remoteSupportItem);
    $root->add($folder);
}

# Method: modelClasses
#
# Overrides:
#
#       <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{

    my ($self) = @_;

    return [
        'EBox::RemoteServices::Model::Subscription',
        'EBox::RemoteServices::Model::AccessSettings',
        'EBox::RemoteServices::Model::RemoteSupportAccess',
       ];

}

# Method: compositeClasses
#
# Overrides:
#
#    <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{
    my ($self) = @_;

    return [ 'EBox::RemoteServices::Composite::General' ];
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
            'title'   => __('Zentyal Cloud Connection'),
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

    my $hostName = EBox::RemoteServices::Auth->new()->valueFromBundle(COMPANY_KEY);
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
    my $url =  EBox::RemoteServices::Auth->new()->valueFromBundle(SITE_HOST_KEY);
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

    my $authRS = new EBox::RemoteServices::Backup();
    my $vpnClient = $authRS->vpnClientForServices();
    return $vpnClient->iface();

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

    my $authRS = new EBox::RemoteServices::Backup();
    my ($ipAddr, $port, $protocol) = @{$authRS->vpnLocation()};

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

    my $authRS = new EBox::RemoteServices::Backup();
    return $authRS->isConnected();
}

# Method: reloadBundle
#
#    Reload the bundle from Zentyal Cloud using the Web Service
#    to do so.
#
#    This method must be called only from post-installation script
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
#    0 - when subscribed, but not connected
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

    if ( $self->isConnected() ) {
        my $version       = $self->version();
        my $bundleVersion = $self->bundleVersion();
        my $bundleGetter  = new EBox::RemoteServices::Bundle();
        my $bundleContent = $bundleGetter->eBoxBundle($version, $bundleVersion, $force);
        if ( $bundleContent ) {
            my $params = EBox::RemoteServices::Subscription->extractBundle($self->eBoxCommonName(), $bundleContent);
            my $confKeys = EBox::Config::configKeysFromFile($params->{confFile});
            EBox::RemoteServices::Subscription->executeBundle($params, $confKeys);
        } else {
            return 2;
        }
    } elsif ( $self->eBoxSubscribed() ) {
        return 0;
    } else {
        throw EBox::Exceptions::External(__('Zentyal must be subscribed to reload the bundle'));
    }
    return 1;
}


# Method: bundleVersion
#
# Returns:
#
#      Int - the bundle version if Zentyal is subscribed
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


# Method: version
#
# Returns:
#
#      String - the ebox-remoteservices package version according to dpkg-query
#
#      0 - otherwise
#
sub version
{
    my $remoteServicesVersion = 0;
    my @output = `dpkg-query -W ebox-remoteservices`;
    foreach my $line (@output) {
        if ($line =~ m/^ebox-remoteservices\s+([\d.]+)/) {
            $remoteServicesVersion = $1;
            last;
        }
    }


    return $remoteServicesVersion;
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

    if ( (not $force) and ($self->st_entry_exists('subscription/level')) ) {
        return $self->st_get_int('subscription/level');
    } else {
        # Ask to the cloud if connected
        if ( $self->isConnected() ) {
            my $cap = new EBox::RemoteServices::Capabilities();
            my $subsLevel = $cap->subscriptionLevel();
            $self->_setSubscription($subsLevel);
            return $subsLevel->{level};
        }
    }
    return -1;
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

    if ( (not $force)
         and ($self->st_entry_exists('subscription/codename')) ) {
        return $self->st_get_string('subscription/codename');
    } else {
        # Ask to the cloud if connected
        if ( $self->isConnected() ) {
            my $cap = new EBox::RemoteServices::Capabilities();
            my $subsLevel = $cap->subscriptionLevel();
            $self->_setSubscription($subsLevel);
            return $subsLevel->{codename};
        }
    }
    return '';

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

    if ( (not $force)
         and ($self->st_entry_exists('subscription/securityUpdates')) ) {
        return $self->st_get_bool('subscription/securityUpdates');
    } else {
        # Ask to the cloud if connected
        if ( $self->isConnected() ) {
            my $cap = new EBox::RemoteServices::Capabilities();
            my $secUpdates = $cap->securityUpdatesAddOn();
            $self->st_set_bool('subscription/securityUpdates', $secUpdates);
            return $secUpdates;
        }
    }
    return '';
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
sub disasterRecoveryAddOn
{
    my ($self, $force) = @_;

    $force = 0 unless defined($force);

    if ( (not $force)
         and ($self->st_entry_exists('subscription/disasterRecovery')) ) {
        return $self->st_get_bool('subscription/disasterRecovery');
    } else {
        # Ask to the cloud if connected
        if ( $self->isConnected() ) {
            my $cap = new EBox::RemoteServices::Capabilities();
            my $disasterRec = $cap->disasterRecoveryAddOn();
            $self->st_set_bool('subscription/disasterRecovery', $disasterRec);
            return $disasterRec;
        }
    }
    return '';
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

    if ( $args{force} or not $self->st_entry_exists('disaster_recovery/username')  ) {
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
        if ( defined($cred->{username}) ) {
            $self->st_set_string('disaster_recovery/username', $cred->{username});
            $self->st_set_string('disaster_recovery/password', $cred->{password});
            $self->st_set_string('disaster_recovery/server',   $cred->{server});
            $self->st_set_int('disaster_recovery/quota', $cred->{quota});
        } else {
            $self->st_delete_dir('disaster_recovery');
            return {};
        }
    }

    return $self->st_hash_from_dir('disaster_recovery');
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
                key    => 'nusers',
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
        my @tmplParams = (
            (soapHandler      => WS_DISPATCHER),
            (caDomain         => $self->_confKeys()->{caDomain}),
            (allowedClientCNs => $self->_allowedClientCNRegexp()),
            (confDirPath      => EBox::Config::conf()),
            (caPath           => CA_DIR),
           );
        EBox::Module::Base::writeConfFileNoCheck(
            $confFile,
            'remoteservices/soap-loc.mas',
            \@tmplParams);
        unless ( -d CA_DIR ) {
            mkdir(CA_DIR);
        }
        my $caLinkPath = $self->_caLinkPath();
        if ( -l $caLinkPath ) {
            unlink($caLinkPath);
        }
        symlink($self->_caCertPath(), $caLinkPath );

        $apacheMod->addInclude($confFile);
    } else {
        unlink($confFile);
        opendir(my $dir, CA_DIR);
        while(my $file = readdir($dir)) {
            # Check if it is a symbolic link file to remove it
            next unless (-l CA_DIR . $file);
            my $link = readlink (CA_DIR . $file);
            # avoid removing the master CA certificate if this is a slavd
            if ($link ne 'masterca.pem') {
                unlink(CA_DIR . $file);
            }
        }
        closedir($dir);
        try {
            $apacheMod->removeInclude($confFile);
        } catch EBox::Exceptions::Internal with {
            # Do nothing if it's already remove
            ;
        };
    }
    # We have to save Apache changes:
    # From GUI, it is assumed that it is done at the end of the process
    # From CLI, we have to call it manually in some way. TODO: Find it!
    # $apacheMod->save();

}

# Assure the VPN connection with our VPN servers is established
sub _establishVPNConnection
{
    my ($self) = @_;

    if ( $self->eBoxSubscribed() ) {
        try {
            my $authConnection = new EBox::RemoteServices::Backup();
            $authConnection->connection();
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
        system(EBox::Config::pkgdata() . 'ebox-get-cronjobs &');
        # Set the subscription level
        system(EBox::Config::pkgdata() . '../ebox-remoteservices/subs-level &');
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
        my @randHours = map { int(rand(24)) } 0 .. 10;
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


# Return the given configuration file from the control center
sub _confKeys
{
    my ($self) = @_;

    unless ( defined($self->{confFile}) ) {
        my $confDir = $self->subscriptionDir();
        $self->{confFile} = (<$confDir/*.conf>)[0];
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

# Return the link name for the CA certificate in the given format
# hashValue.0 - hash value is the output from openssl ciphering
sub _caLinkPath
{
    my ($self) = @_;

    my $caCertPath = $self->_caCertPath();
    my $hashRet = EBox::Sudo::command("openssl x509 -hash -noout -in $caCertPath");

    my $hashValue = $hashRet->[0];
    chomp($hashValue);
    return CA_DIR . "${hashValue}.0";
}

# Return the Control Center connection widget to be shown in the dashboard
sub _ccConnectionWidget
{
    my ($self, $widget) = @_;

    if ( $self->eBoxSubscribed() ) {
        my $section = new EBox::Dashboard::Section('connection_section');
        $widget->add($section);
        my $msg = __x('Not connected. Check VPN logs in {path}',
                      path => EBox::Config::log() . 'openvpn/');
        my $valueType = 'warning';
        if ( $self->isConnected() ) {
            $msg = __('Connected');
            $valueType = 'info';
        }
        $section->add(new EBox::Dashboard::Value(__('Zentyal Cloud'), $msg, $valueType));
    }
}

# set the subscription level
sub _setSubscription
{
    my ($self, $subsLevel) = @_;

    $self->st_set_int('subscription/level', $subsLevel->{level});
    $self->st_set_string('subscription/codename', $subsLevel->{codename});

}

# Method: extaSudoerUser
#
#  Returns:
#    list with usernames to add to the system' sudoer users
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

    my $stringConf = '';
    my @settings = (
                    ['subscribed', 'bool'],
                    ['just_subscribed', 'bool'],
                    # form
                    ['Subscription/eboxCommonName', 'string'],
                    ['Subscription/username', 'string'],
                    # cache

               );

    foreach my $setting (@settings) {
        my ($key, $type) = @{ $setting };
        my $getter = "st_get_" . $type;
        my $value = $self->$getter($key);
        $stringConf .= "$key,$type,$value\n";
    }
    # file with subscription conf parameters
    my $subscriptionConfFile = $self->_backupSubscritionConf($dir);
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

    # restore st conf
    my @lines = File::Slurp::read_file($subscriptionConf);
    foreach my $line  (@lines) {
        chomp $line;
        my ($key,$type,$value) = split ',', $line;
        my $setter = "st_set_" . $type;
        if (defined $value) {
            $self->$setter($key, $value);
        } else {
            $self->unset($key); # remove previous key..
        }

    }

    # restore subscription files and ownerhsip
    my $tarPath = $self->_backupSubscritionTar($dir);
    my $tarCmd = 'tar x --file ' . $tarPath . ' -C /';
    EBox::Sudo::root($tarCmd);

    my $subscriptionDir =  SUBS_DIR;
    EBox::Sudo::root("chown ebox.adm '$subscriptionDir'");
    EBox::Sudo::root("chown -R ebox.ebox $subscriptionDir*");
}

sub clearCache
{
    my ($self) = @_;

    my @cacheDirs = qw(subscription disaster_recovery);
    foreach my $dir (@cacheDirs) {
        $self->st_delete_dir($dir);
    }
}

1;
