# Copyright (C) 2008-2014 Zentyal S.L.
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

# Class: EBox::RemoteServices
#
#      RemoteServices module to handle everything related to the remote
#      services offered
#

package EBox::RemoteServices;
use base qw(EBox::Module::Config);

use EBox::Config;
use EBox::Dashboard::ModuleStatus;
use EBox::Dashboard::Section;
use EBox::Dashboard::Value;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::RESTRequest;
use EBox::Exceptions::Command;
use EBox::Gettext;
use EBox::Global;
use EBox::Menu::Folder;
use EBox::Menu::Item;
use EBox::RemoteServices::Backup;
use EBox::RemoteServices::Exceptions::NotCapable;
use EBox::RemoteServices::QAUpdates;
use EBox::RemoteServices::Subscription::Check;
use EBox::RemoteServices::RESTResource::Auth;
use EBox::RemoteServices::RESTResource::Community;
use EBox::RemoteServices::RESTResource::ConfBackup;
use EBox::RemoteServices::RESTResource::Subscriptions;
use EBox::RemoteServices::Subscription::Validate;
use EBox::Sudo;
use EBox::Util::Version;
use EBox::Validate;
use EBox::WebAdmin::PSGI;

use AptPkg::Cache;
use File::Slurp;
use JSON::XS;
use POSIX;
use YAML::XS;
use TryCatch::Lite;
use Date::Calc;

use constant COMMERCIAL_EDITION      => EBox::Config::home() . '.commercial-edition';
use constant CRON_FILE               => '/etc/cron.d/zentyal-remoteservices';
use constant PROF_PKG                => 'zentyal-cloud-prof';
use constant SUBSCRIPTION_LEVEL_NONE => -1;
use constant SUBSCRIPTION_LEVEL_COMMUNITY => 0;
use constant SYNC_PKG                => 'zfilesync';

use constant RELEASE_UPGRADE_MOTD => '/etc/update-motd.d/91-release-upgrade';

my %i18nLevels = ( '-1' => __('Unknown'),
                   '0'  => __('Community'),
                   '5'  => __('Small Business'),
                   '6'  => __('Professional'),
                   '7'  => __('Business'),
                   '8'  => __('Trial'),
                   '9'  => __('Commercial'),
                   '10' => __('Enterprise'),
                   '20' => __('Premium'));
my %codenameLevels = ( 'basic'        => SUBSCRIPTION_LEVEL_COMMUNITY,
                       'professional' => 6,
                       'business'     => 7,
                       'trial'        => 8,
                       'commercial'   => 9,
                       'premium'      => 20 );


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

# Method: commercialEdition
#
#     Get whether this installation is a commercial one or not
#
# Parameters:
#
#     force - Boolean indicating to do the check again
#
# Returns:
#
#     Boolean
#
sub commercialEdition
{
    my ($self, $force) = @_;
    unless (exists $self->{commercialEdition} or $force) {
        $self->{commercialEdition} = (-e COMMERCIAL_EDITION);
    }
    return $self->{commercialEdition}
}

# we override aroundRestoreconfig to restore also state data (for subscription/registration)
sub aroundRestoreConfig
{
    my ($self, $dir, @extraOptions) = @_;
    $self->SUPER::aroundRestoreConfig($dir, @extraOptions);
    $self->_load_state_from_file($dir);
    # remove last backup date because it is not reliable after backup
    EBox::RemoteServices::Backup->new()->setLatestRemoteConfBackup(undef);
}

# Method: subscriptionLevel
#
#      Get the subscription level. This is a way to order editions
#      within the Zentyal Server realm as Remote side is now deprecated.
#
# Returns:
#
#      Int - the subscription level
#
#         -1 - no subscribed or impossible to know
#          0 - basic/community
#          6 - professional
#          7 - business
#          8 - trial
#          9 - commercial
#          20 - premium
#
sub subscriptionLevel
{
    my ($self) = @_;

    if (not $self->eBoxSubscribed()) {
        return SUBSCRIPTION_LEVEL_NONE;
    } elsif (not $self->commercialEdition()) {
        return SUBSCRIPTION_LEVEL_COMMUNITY;
    }

    my $codeName = $self->subscriptionCodename();
    unless (exists $codenameLevels{$codeName}) {
        return SUBSCRIPTION_LEVEL_NONE;
    }
    return $codenameLevels{$codeName};
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

    my $level = -2;
    try {
        my $subscriptionInfo;
        if ($force) {
            $subscriptionInfo = $self->refreshSubscriptionInfo();
        } else {
            $subscriptionInfo = $self->subscriptionInfo;
        }
        $level = $subscriptionInfo->{features}->{technical_support}->{level};
        unless (defined($level)) {
            $level = -1;
        }
    } catch ($ex) {
        EBox::error("Error getting technical support level: $ex");
    }

    return $level;
}

# Method: username
#
#     Get the stored username
#
# Returns:
#
#     String
#
sub username
{
    my ($self) = @_;
    $self->get_state()->{'username'};
}

# Method: setUsername
#
#     Set the username
#
# Parameters:
#
#     username - String
#
sub setUsername
{
    my ($self, $username) = @_;
    # Validate in server side
    if (not $username) {
        throw EBox::Exceptions::External('username');
    }
    my $state = $self->get_state();
    $state->{'username'} = $username;
    $self->set_state($state);
}

# Method: refreshSubscriptionInfo
#
#     Refresh subscription information.
#
#     If the subscription is not valid anymore, then unsubscribe is done.
#
#     If we can't contact the server, the cached data is returned.
#
# Parameters:
#
#     username - String
#
# Returns:
#
#     Hash ref - what <subscriptionInfo> returns.
#
sub refreshSubscriptionInfo
{
    my ($self) = @_;
    my $subscriptionInfo;
    my $refreshError = 0;

    if ($self->subscriptionCredentials()) {
        try {
            my $subscriptions = $self->subscriptionsResource();
            $subscriptionInfo = $subscriptions->subscriptionInfo();
        } catch (EBox::Exceptions::RESTRequest $ex) {
            if ($ex->code() == 403) {
                # forbidden, the subscription is not valid anymore
                EBox::warn("Subscription expired or revoked");
                $subscriptionInfo = undef;
            } else {
                $refreshError = $ex;
            }
        } catch ($ex) {
            $refreshError = $ex;
        }
    } else {
        $self->_removeSubscriptionData(); # remove any leftover which should not
                                          # be in first place
        return;
    }

    if ($refreshError) {
        EBox::warn("Cannot refresh subscription information, using cached data: $refreshError");
        $subscriptionInfo = $self->subscriptionInfo();
        if ($subscriptionInfo and (not $self->_checkSubscriptionAlive($subscriptionInfo))) {
            EBox::warn("Subscription expired");
            $subscriptionInfo = undef;
        }
    }

    if (not $subscriptionInfo) {
        try {
            if ($self->commercialEdition('force')) {
                $self->unsubscribe();
            } else {
                $self->unregisterCommunityServer();
            }
        } catch ($ex) {
            EBox::error("Error unsubscribing $ex");
        }
        return undef;
    }

    $self->_setSubscriptionInfo($subscriptionInfo);
    return $subscriptionInfo;
}

# Method: subscriptionInfo
#
#     Return the stored subscription information.
#
#     It is updated every 24h.
#
# Returns:
#
#     Hash ref - with all information. I hope the example clarifies it.
#
# Example:
#
#     {
#          'subscription_end' => '2023-03-02 23:23:21',
#          'subscription_start' => '2014-08-07 16:12:00',
#          'is_server' => bless( do{\(my $o = 1)}, 'JSON::XS::Boolean' ),
#          'label' => 'Zentyal Professional Edition (host: the-horrors)',
#          'server' => {
#                        'uuid' => 'e7e7cd08a1784f5ea601857b671e54b6',
#                        'name' => 'the-horrors'
#                      },
#          'features' => {
#                          'technical_support' => {
#                                                   'sla' => 'Two business days',
#                                                   'level' => 0,
#                                                   'label' => 'Standard Technical Support 2 days'
#                                                 }
#                        },
#          'subscription_uuid' => 'b996f64e91974abdb3ab825c46dd78d7',
#          'messages' => '',
#          'product_code' => 'ZS-PROF-Y1',
#          'product_label' => 'Small Business Edition server',
#          'company' => {
#                         'name' => 'par',
#                         'description' => 'Even client',
#                         'uuid' => 'adc203a219034802bbbd91b54314519c'
#                       },
#          'remote_domain' => 'cloud.zentyal.com',
#          'username' => 'foo@bar.org'
#        };
#
sub subscriptionInfo
{
    my ($self) = @_;
    my $subsInfo = $self->get_state()->{'subscription_info'};
    if ($subsInfo) {
        my $adMsgs = $self->adMessages();
        $subsInfo->{messages} = $adMsgs->{text};
        $subsInfo->{username} = $self->username();
    }

    return $subsInfo;
}

# Method: subscriptionCredentials
#
#      Get the subscription credentials.
#
#      Undef if it is not registered.
#
# Returns:
#
#      Hash ref - with the following keys:
#
#         server_uuid - the UUID of the server
#         subscription_uuid - the UUID of the subscription
#         name - the server's name
#         password - the server's password
#         product_code - whatever
#
sub subscriptionCredentials
{
    my ($self) = @_;
    return $self->get_state()->{'subscription_credentials'};
}

# Method: subscribe
#
#      Subscribe a server
#
# Parameters:
#
#      name - String the server's name
#
#      password - String the user's password. Use <setUsername> to set
#                 the user
#
#      uuid - String the subscription's identifier to use
#
#      mode - String the mode. Options: new, associate and overwrite.
#
# Returns:
#
#      Hash ref - what <refreshSubscriptionInfo> returns
#
# Exceptions:
#
#      <EBox::Exceptions::Internal> - thrown if we trying to subscribe
#      a community edition
#
sub subscribe
{
    my ($self, $name, $password, $uuid, $mode) = @_;
    if (not $self->commercialEdition()) {
        throw EBox::Exceptions::Internal('Cannot subscribe a community edition');
    }

    my $subscriptions = $self->subscriptionsResource($password);
    my $subscriptionCred = $subscriptions->subscribeServer($name, $uuid, $mode);

    # Mark webadmin as changed to reload composites + themes
    $self->global()->addModuleToPostSave('webadmin');

    $self->_setSubscriptionCredentials($subscriptionCred);

    my $subscriptionInfo = $self->refreshSubscriptionInfo();

    $self->setAsChanged(1);

    return $subscriptionInfo;
}

# Method: unsubscribe
#
#      Unsubscribe a server
#
# Parameters:
#
#      password - String the user's password. Use <setUsername> to set
#                 the user (Optional)
#
# Exceptions:
#
#      <EBox::Exceptions::Internal> - thrown if we trying to unsubscribe
#      a community edition
#
sub unsubscribe
{
    my ($self, $password) = @_;
    if (not $self->commercialEdition()) {
        throw EBox::Exceptions::Internal('Cannot unsubscribe a community edition');
    }


    # Check no other modules required to be subscribed
    EBox::RemoteServices::Subscription::Check::unsubscribeIsAllowed();

    if ($self->username() and $password) {
        my $subscriptions  = $self->subscriptionsResource($password);
        $subscriptions->unsubscribeServer();
    }
    $self->_removeSubscriptionData();

    # remove packages added with the subscription
    $self->_downgrade();

    # Mark webadmin as changed to reload composites + themes
    $self->global()->addModuleToPostSave('webadmin');

    $self->setAsChanged(1);
}

# Method: registerFirstCommunityServer
#
#      Register a community server for the first time
#
# Parameters:
#
#      username - String the user's name
#
#      servername - String the server's name
#
#      newsletter - Boolean the newsletter
#
# Exceptions:
#
#      <EBox::Exceptions::Internal> - thrown if we trying to subscribe
#      a commercial edition
#
sub registerFirstCommunityServer
{
    my ($self, $username, $servername, $newsletter) = @_;

    if ($self->commercialEdition()) {
        throw EBox::Exceptions::Internal('Register community server is only for community editions');
    }

    EBox::Validate::checkEmailAddress($username, __('mail address'));
    EBox::RemoteServices::Subscription::Validate::validateServerName($servername);

    $self->setUsername($username);

    my $community = $self->communityResource();
    my $credentials = $community->subscribeFirstTime($username, $servername, $newsletter);
    $self->_setSubscriptionCredentials($credentials);

    my $subscriptions = $self->subscriptionsResource();
    my $subscriptionInfo = $subscriptions->subscriptionInfo();
    $self->_setSubscriptionInfo($subscriptionInfo);

    $self->setAsChanged(1);
}

# Method: registerFirstCommunityServer
#
#      Register a community server for the first time
#
# Parameters:
#
#      username - String the user's name
#
#      password - String the user's password
#
#      servername - String the server's name
#
# Exceptions:
#
#      <EBox::Exceptions::Internal> - thrown if we trying to register
#      a commercial edition
#
sub registerAdditionalCommunityServer
{
    my ($self, $username, $password, $servername) = @_;

    if ($self->commercialEdition()) {
        throw EBox::Exceptions::Internal('Register community server is only for community editions');
    }

    EBox::Validate::checkEmailAddress($username, __('mail address'));
    EBox::RemoteServices::Subscription::Validate::validateServerName($servername);

    $self->setUsername($username);

    my $community = $self->communityResource($password);
    my $credentials = $community->subscribeAdditionalTime($servername);
    $self->_setSubscriptionCredentials($credentials);

    my $subscriptions = $self->subscriptionsResource();
    my $subscriptionInfo = $subscriptions->subscriptionInfo();
    $self->_setSubscriptionInfo($subscriptionInfo);

    $self->setAsChanged(1);
}

# Method: unregisterCommunityServer
#
#     Delete all information from a community server.
#
# Exceptions:
#
#      <EBox::Exceptions::Internal> - thrown if we trying to unregister
#      a commercial edition
#
sub unregisterCommunityServer
{
    my ($self) = @_;

    if ($self->commercialEdition()) {
        throw EBox::Exceptions::Internal('Unregister server is only for community editions');
    }

    $self->_removeSubscriptionData();

    $self->setAsChanged(1);
}

sub _removeSubscriptionData
{
    my ($self) = @_;
    my $state = $self->get_state();
    delete $state->{'username'};
    delete $state->{'subscription_credentials'};
    delete $state->{'subscription_info'};
    delete $state->{'latest_backup_date'};
    $self->set_state($state);
}

# Method: REST
#
#   Return the REST client ready to query remote services.
#
# Exceptions:
#
#   <EBox::Exceptions::Internal> - thrown if the server is not
#   subscribed
#
sub REST
{
    my ($self) = @_;

    unless ($self->{rest}) {
        my $restRes = new EBox::RemoteServices::RESTResource(remoteservices => $self);
        $self->{rest} = $restRes->restClientWithServerCredentials();
    }

    return $self->{rest};
}

# Method: subscriptionsResource
#
# Parameters:
#
#     userPassword - String (Optional)
#
# Returns:
#
#     <EBox::RemoteServices::RESTResource::Subscriptions>
#
sub subscriptionsResource
{
    my ($self, $userPassword) = @_;
    my $subscriptions = EBox::RemoteServices::RESTResource::Subscriptions->new(remoteservices => $self,
                                                                 userPassword   => $userPassword
                                                                );
    return $subscriptions;
}

# Method: confBackupResource
#
# Returns:
#
#     <EBox::RemoteServices::RESTResource::ConfBackup>
#
sub confBackupResource
{
    my ($self) = @_;
    return EBox::RemoteServices::RESTResource::ConfBackup->new(remoteservices => $self);
}

# Method: communityResource
#
# Parameters:
#
#     userPassword - String (Optional)
#
# Returns:
#
#     <EBox::RemoteServices::RESTResource::Community>
#
sub communityResource
{
    my ($self, $userPassword) = @_;
    my $community = EBox::RemoteServices::RESTResource::Community->new(remoteservices => $self,
                                                                 userPassword   => $userPassword
                                                                );
    return $community;
}

# Method: latestRemoteConfBackup
#
# Get the last time when a configuration backup (manual or
# automatic) has been done
#
# Returns:
#
# String - the date in RFC 2822 format
#
# 'unknown' - if the date is not available
#
sub latestRemoteConfBackup
{
    my ($self) = @_;

    my $bakService = new EBox::RemoteServices::Backup();
    return $bakService->latestRemoteConfBackup();
}

# Method: authResource
#
# Parameters:
#
#     userPassword - String (Optional)
#
# Returns:
#
#     <EBox::RemoteServices::RESTResource::Auth>
#
sub authResource
{
    my ($self, $userPassword) = @_;
    return EBox::RemoteServices::RESTResource::Auth->new(remoteservices => $self,
                                           userPassword  => $userPassword);
}

# Method: eBoxSubscribed
#
#     Determine if the server is subscribed/registered.
#
# Returns:
#
#     Boolean
#
sub eBoxSubscribed
{
    my ($self) = @_;
    my $info = $self->subscriptionInfo();
    return defined($info);
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
        my $info = $self->subscriptionInfo();
        return $info->{server}->{name};
    } else {
        return undef;
    }

}

# Method: cloudDomain
#
#        Return the Zentyal Cloud Domain if the server is subscribed.
#
#        Undef otherwise.
#
# Returns:
#
#        String - the Zentyal Cloud Domain
#
sub cloudDomain
{
    my ($self) = @_;
    my $info = $self->subscriptionInfo();
    if (not $info) {
        return undef;
    }
    return $info->{remote_domain};
}

# Method: i18nServerEdition
#
#     Get the server edition printable name
#
# Returns:
#
#     String - the printable edition. Unknown if there is no
#     subscription information
#
sub i18nServerEdition
{
    my ($self) = @_;

    my $si = $self->subscriptionInfo();
    if ($si) {
        return $si->{product_label};
    } else {
        return __('Unknown');
    }
}

# Method: subscriptionCodename
#
#      Get the subscription codename
#
#
# Returns:
#
#      String - the subscription codename
#
#         '' - no subscribed or impossible to know
#         basic
#         professional
#         business
#         enterprise
#         trial
#         commercial
#
sub subscriptionCodename
{
    my ($self) = @_;

    my $subscriptionInfo = $self->subscriptionInfo;
    if ((not $subscriptionInfo) or (not exists $subscriptionInfo->{'codename'})) {
        return '';
    }

    return $subscriptionInfo->{'codename'};
}

# Method: addOnAvailable
#
#      Return 1 if addon is available, undef if not
#
# Parameters:
#
#      addOn - String the add-on name to get the details from
#
#
sub addOnAvailable
{
    my ($self, $addOn) = @_;

    my $subsInfo = $self->subscriptionInfo();
    my $ret = 0;

    if ($subsInfo) {
        $ret = (exists $subsInfo->{features}->{$addOn});
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
# Returns:
#
#      Hash ref - indicating the add-on details
#                 Empty hash if no add-on is there for this server
#
sub addOnDetails
{
    my ($self, $addOn) = @_;

    my $subsInfo = $self->subscriptionInfo();
    my $ret = {};

    if ($subsInfo and exists $subsInfo->{features}->{$addOn}) {
        $ret = $subsInfo->{features}->{$addOn};
    }

    return $ret;
}

# Method: subscribedUUID
#
#        Return the server UUID if this is subscribed to Zentyal
#        Remote
#
# Returns:
#
#        String - the UUID
#
# Exceptions:
#
#        <EBox::Exceptions::Internal> - thrown if the host is not
#        subscribed to Zentyal Remote
#
sub subscribedUUID
{
    my ($self) = @_;

    my $si = $self->subscriptionInfo();
    unless ($si) {
        throw EBox::Exceptions::Internal('subscribedUUID cannot be called if there is no subscription info');
    }

    return $si->{server}->{uuid};
}

# Method: _setConf
#
#      Do the subscription here.
#
# Overrides:
#
#      <EBox::Module::Base::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    # create dir for remoteservices configuration
    # for the moment is used only to store lastbackup timestamp
    my $dir   = EBox::Config::conf() . 'remoteservices';
    my $user  = EBox::Config::user();
    my $group = EBox::Config::group();
    EBox::Sudo::root("mkdir -p '$dir'",
                     "chown $user.$group '$dir'"
                    );


    my $subscriptionInfo = $self->refreshSubscriptionInfo();
    my $subscriptionLevel = $self->subscriptionLevel();
    $self->_setupSubscription($subscriptionLevel, $subscriptionInfo);

    $self->_updateMotd();
}



sub _setupSubscription
{
    my ($self, $subscriptionLevel, $subscriptionInfo) = @_;

    EBox::RemoteServices::QAUpdates::set($self->global(), $subscriptionLevel);
    $self->_manageCloudProfPackage($subscriptionLevel);
    $self->_writeCronFile($subscriptionLevel >= 0);
}

sub _writeCronFile
{
    my ($self, $subscribed) = @_;

    if ($subscribed) {
        # the cron file contains automatic-conf-backup and refresh-subscription
        # which are for all levels

        my $hours = $self->st_get_list('rand_hours');
        unless ( @{$hours} > 0 ) {
            # Set the random times when scripts must ask for information
            my @randHours = map
              { my $r = int(rand(9)) - 2; $r += 24 if ($r < 0); $r }
                0 .. 10;
            my @randMins  = map { int(rand(60)) } 0 .. 10;
            $self->st_set_list('rand_hours', 'int', \@randHours);
            $self->st_set_list('rand_mins' , 'int', \@randMins);
            $hours = \@randHours;
        }

        my $mins = $self->st_get_list('rand_mins');

        my @tmplParams = (
            ( hours => $hours), (mins => $mins)
           );

        EBox::Module::Base::writeConfFileNoCheck(
            CRON_FILE,
            'core/remoteservices/zentyal-remoteservices.cron.mas',
            \@tmplParams);
    } else {
        EBox::Sudo::root("rm -f '" . CRON_FILE . "'");
    }
}

sub _checkSubscriptionAlive
{
    my ($self, $subscriptionInfo) = @_;
    if (not $subscriptionInfo) {
         return 0;
     }

    my $end  = $subscriptionInfo->{subscription_end};
    if (not $end) {
        # subscription without end date
        return 1;
    }

    my ($sec,$min,$hour,$mday,$mon,$year) = gmtime();
    $year += 1900;
    $mon  += 1;
    # give five day margin
    my $margin = 5;
    ($year, $mon, $mday) = Date::Calc::Add_Delta_Days($year, $mon, $mday, -$margin);

    my $gmtime = sprintf('%04d-%02d-%02d %02d:%02d:%02d', $year, $mon, $mday, $hour, $min, $sec);
    return ($gmtime lt $end);
}

sub _manageCloudProfPackage
{
    my ($self, $subscriptionLevel) = @_;
    my $installed = $self->_pkgInstalled(PROF_PKG);
    if ($subscriptionLevel < 1) {
        if ($installed) {
            $self->_downgrade();
        }
        return;
    }

    if (not $installed) {
        $self->_installProfPkgs();
    }
}

# Update MOTD scripts depending on the subscription status
sub _updateMotd
{
    my ($self) = @_;

    my @tmplParams = (
         (subscribed => $self->eBoxSubscribed())
        );
    if ($self->eBoxSubscribed() ) {
        push(@tmplParams, (editionMsg => __sx('This is a Zentyal Server ({edition}).',
                                                edition => $self->i18nServerEdition())));
    }
    EBox::Module::Base::writeConfFileNoCheck(
        RELEASE_UPGRADE_MOTD,
        'core/remoteservices/release-upgrade-motd.mas',
        \@tmplParams, { mode => '0755' });

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
#    Check if we have to remove any ad message.
#
sub checkAdMessages
{
    my ($self) = @_;

    if ($self->eBoxSubscribed()) {
        # Launch our checker to see if the max_users message disappear
        my $checker = new EBox::RemoteServices::Subscription::Check();
        $checker->check($self->subscriptionInfo());
    }
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

    if ($self->addOnAvailable('serverusers')) {
        $max_users = $self->addOnDetails('serverusers')->{max};
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
        return $self->addOnDetails('cloudusers')->{max_users};
    }
    return 0;
}

# Method: filesSyncAvailable
#
#   Returns 1 if file synchronisation is available
#
sub filesSyncAvailable
{
    my ($self) = @_;

    return $self->addOnAvailable('cloudfiles');
}

# Method: maxConfBackups
#
#   Return the maximum number of manual configuration backups
#
# Returns:
#
#   Int - the number of manual configuration backups available
#
sub maxConfBackups
{
    my ($self) = @_;

    my $ret = 0;
    my $confBackupDetails = $self->addOnDetails('configuration_backup');

    if ($confBackupDetails) {
        $ret = $confBackupDetails->{'backup_limit_manual'};
    }
    return $ret;
}

# Method: menu
#
# Overrides:
#
#       <EBox::Module::Base::menu>
#
sub menu
{
    my ($self, $root) = @_;

    # Subscription menu is only for commercial editions
    if (not $self->commercialEdition()) {
        return undef;
    }

    my $system = new EBox::Menu::Folder('name' => 'SysInfo',
                                        'icon' => 'system',
                                        'text' => __('System'),
                                        'tag' => 'system',
                                        'order' => 30);

    $system->add(new EBox::Menu::Item('url'   => 'SysInfo/RemoteServices',
                                      'text'  => __('Server Edition'),
                                      'order' => 30,
                                     ));

    $root->add($system);
}

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

# Method: wizardPages
#
# Overrides:
#
#       <EBox::Module::Base::wizardPages>
#
sub wizardPages
{
    my ($self) = @_;

    if (EBox::Config::configkey('hide_subscription_wizard') or $self->commercialEdition('force')) {
        return [];
    }

    return [{ page => '/RemoteServices/Wizard/Subscription', order => 10000 }];
}


# Method: widgets
#
# Overrides#
#    <EBox::Module::Base::widgets>
#
sub widgets
{
    my ($self) = @_;

    return {
        'ccConnection' => {
            'title'   => __('Server Information'),
            'widget'  => \&_ccConnectionWidget,
            'order'  => 4,
            'default' => 1,
        }
       };

}

# Return the Zentyal Cloud connection widget to be shown in the dashboard
sub _ccConnectionWidget
{
    my ($self, $widget) = @_;

    my $section = new EBox::Dashboard::Section('cloud_section');
    $widget->add($section);

    my ($serverName, $edition, $lastBackupValue) =
      ( __('None'), '', __('Disabled'));

    my $supportValue = __x('Disabled - {oh}Enable{ch}',
                           oh => '<a href="/RemoteServices/Composite/Technical">',
                           ch => '</a>');

    my $commercialEdition = $self->commercialEdition();

    if ( $self->eBoxSubscribed() ) {
        $serverName = $self->eBoxCommonName();

        $edition = $self->i18nServerEdition();

        my %i18nSupport = ( '-2' => __('Unknown'),
                            '-1' => $supportValue,
                            '0'  => __('Standard 2 days'),
                            '1'  => __('Standard 1 day'),
                            '2'  => __('Standard 4 hours'),
                            '3'  => __('Premium'));
        $supportValue = $i18nSupport{$self->technicalSupport()};

        $lastBackupValue = __x('Configuration backup enabled');
        my $date;
        try {
            $date = $self->latestRemoteConfBackup();
            if (not $date) {
                $date = __('none');
            }
        } catch {
            $date = __('unknown');
        };
        $lastBackupValue .= ' ' . __x('- Latest conf backup: {date}', date => $date);
    } elsif (not $commercialEdition) {
        $lastBackupValue = __sx('{oh}Register to store your backups in the cloud{ch}',
                                oh => '<a href="/RemoteServices/Backup/Index">',
                                ch => '</a>');
    }

    $section->add(new EBox::Dashboard::Value(__('Server name'), $serverName));

    $section->add(new EBox::Dashboard::Value(__('Server edition'),
                                             $edition));
    if ($commercialEdition) {
        $section->add(new EBox::Dashboard::Value(__('Technical support'),
                                                 $supportValue));
    } elsif ($self->eBoxSubscribed()) {
        $section->add(new EBox::Dashboard::Value(__('Registered e-mail'),
                                                 $self->username()));
    }
    $section->add(new EBox::Dashboard::Value(__s('Configuration backup'),
                                             $lastBackupValue));
}

# Check if a package is already installed
sub _pkgInstalled
{
    my ($self, $pkg) = @_;

    my $installed = 0;
    my $cache = new AptPkg::Cache();
    if ( $cache->exists($pkg) ) {
        my $pkg = $cache->get($pkg);
        $installed = ( $pkg->{SelectedState} == AptPkg::State::Install
                       and $pkg->{InstState} == AptPkg::State::Ok
                       and $pkg->{CurrentState} == AptPkg::State::Installed );
    }
    return $installed;
}

sub _setSubscriptionInfo
{
    my ($self, $cred) = @_;
    my $state = $self->get_state();
    $state->{'subscription_info'} =  $cred;
    $self->set_state($state);
}

sub _setSubscriptionCredentials
{
    my ($self, $cred) = @_;
    my $state = $self->get_state();
    $state->{'subscription_credentials'} =  $cred;
    $self->set_state($state);
}

# Install professional packages
sub _installProfPkgs
{
    my ($self) = @_;

    my @packages = (PROF_PKG);
    my $locale = EBox::locale();
    my ($lang) = $locale =~ m/^(.*?)_/;
    if ( defined($lang) and ($lang eq 'es') ) {
        push(@packages, "language-pack-zentyal-prof-$lang");
    }

    my $gl = $self->global();
    try {
        if ( $gl->modExists('software') ) {
            my $software = $gl->modInstance('software');
            $software->updatePkgList();
            for my $pkg (@packages) {
                my $progress = $software->installPkgs($pkg);
                while (not $progress->finished() ) {
                    sleep(9);
                    EBox::info('Message: ' . $progress->message());
                    EBox::info("Installing $pkg ( " . $progress->percentage() . '%)');
                }
            }
        } else {
            EBox::Sudo::root('apt-get update -q');
            my $cmd = 'apt-get install -q --yes --force-yes --no-install-recommends '
              . '-o DPkg::Options::="--force-confold"';
            my $param = "DEBIAN_FRONTEND=noninteractive $cmd " . join(' ', @packages);
            EBox::info('Installing ' . join(' ', @packages));
            EBox::Sudo::root($param);
        }
    } catch ($e) {
        EBox::error("Cannot install packages: $e");
    }
}

# Downgrade
sub _downgrade
{
    my ($self) = @_;

    # Remove packages if basic subscription or no subscription at all

    # Remove pkgs using at to avoid problems when doing so from Zentyal UI
    my @packages = (PROF_PKG, SYNC_PKG);
    @packages = grep { $self->_pkgInstalled($_) } @packages;

    return unless ( @packages > 0 );

    my $gl = $self->global();
    try {
        if ( $gl->modExists('software') ) {
            my $software = $gl->modInstance('software');
            my $progress = $software->removePkgs(@packages);
            while (not $progress->finished() ) {
                sleep(9);
                EBox::info('Message: ' . $progress->message());
                EBox::info('Uninstalling ' . join(' ', @packages) . ' ( ' . $progress->percentage() . '%)');
            }
        } else {
            my $cmd = 'apt-get remove --purge -q --yes '
              . '-o DPkg::Options::="--force-confold"';
            my $param = "DEBIAN_FRONTEND=noninteractive $cmd " . join(' ', @packages);
            EBox::info('Uninstalling ' . join(' ', @packages));
            EBox::Sudo::root($param);
        }
    } catch ($e) {
        EBox::error('These packages ' . join(' ', @packages) . ' cannot be uninstalled: ' . $e->stringify());
    }
}

1;
