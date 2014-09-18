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

use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::RESTRequest;
use EBox::Exceptions::Command;

use EBox::Sudo;
use EBox::Util::Version;
use EBox::Validate;
use EBox::WebAdmin::PSGI;

use AptPkg::Cache;
use File::Slurp;
use JSON::XS;
use Net::DNS;
use POSIX;
use YAML::XS;
use TryCatch::Lite;


use constant CRON_FILE               => '/etc/cron.d/zentyal-remoteservices';
use constant PROF_PKG                => 'zentyal-cloud-prof';
use constant REMOVE_PKG_SCRIPT       => EBox::Config::scripts() . 'remove-pkgs';
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
                   '10' => __('Enterprise'),
                   '20' => __('Premium'));
my %codenameLevels = ( 'basic'        => 0,
                       'professional' => 6,
                       'business'     => 7,
                       'trial'        => 8,
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

# TODO see if this continues to make sense
#    EBox::Sudo::root('chown -R ebox:adm ' . EBox::Config::conf() . 'remoteservices');
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
#          0 - basic
#          6 - professional
#          7 - business
#          8 - trial
#          20 - premium
#
sub subscriptionLevel
{
    my ($self) = @_;

    if (not $self->eBoxSubscribed()) {
        my $serverCredentials = $self->subscriptionCredentials();
        if ($serverCredentials and (not defined $serverCredentials->{subscription_uuid})) {
            return SUBSCRIPTION_LEVEL_COMMUNITY;
        }
        return SUBSCRIPTION_LEVEL_NONE;
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
    } catch ($ex) {
        EBox::error("Error getting technical support level: $ex");
    }

    return $level;
}

# FIXME: Missing doc
sub username
{
    my ($self) = @_;
    $self->get('username');
}

# FIXME: Missing doc
sub setUsername
{
    my ($self, $username) = @_;
        # TODO validate
    if (not $username) {
        throw EBox::Exceptions::External('username');
    }
    $self->set('username', $username);
}

# FIXME: Missing doc
sub refreshSubscriptionInfo
{
    my ($self) = @_;
    my $subscriptionInfo;
    try {
        my $subscriptions = $self->subscriptionsResource();
        $subscriptionInfo = $subscriptions->subscriptionInfo();
    } catch (EBox::Exceptions::RESTRequest $ex) {
        if ($ex->code() == 403 ) {
            # forbidden, the subscripption is not valid anymore
            EBox::warn("Subscription expired or revoked");
            $subscriptionInfo = undef;
        } else {
            EBox::warn("Cannot refresh subscription information, using cached data: $ex");
            $subscriptionInfo = $self->subscriptionInfo();
        }
    } catch ($ex) {
        EBox::warn("Cannot refresh subscription information, using cached data: $ex");
        $subscriptionInfo = $self->subscriptionInfo();
    }

    if ($subscriptionInfo and (not $self->_checkSubscriptionAlive($subscriptionInfo))) {
        EBox::warn("Subscription expired");
        $subscriptionInfo = undef;
    }

    if (not $subscriptionInfo) {
        try {
            $self->unsubscribe();
        } catch ($ex) {
            EBox::debug('Already unsubscribed');
        }
        return undef;
    }

    $self->setSubscriptionInfo($subscriptionInfo);
    return $subscriptionInfo;
}

# FIXME: Missing doc
sub setSubscriptionInfo
{
    my ($self, $cred) = @_;
    $self->set('subscription_info', $cred);
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
    my $subsInfo = $self->get('subscription_info');
    if ($subsInfo) {
        my $adMsgs = $self->adMessages();
        $subsInfo->{messages} = $adMsgs->{text};
        $subsInfo->{username} = $self->username();
    }

    return $subsInfo;
}

# FIXME: Missing doc
sub setSubscriptionCredentials
{
    my ($self, $cred) = @_;
    $self->set('subscription_credentials', $cred);
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
    return $self->get('subscription_credentials');
}

sub setCommunityRegistration
{
    my ($self, $cred) = @_;
    if (not $cred) {
        throw EBox::Exceptions::MissingArgument('cred');
    }
    $self->setSubscriptionCredentials($cred);
    $self->_saveConfig();

    # it is assumne the only changes are the usernme + subscription credentials
    $self->setAsChanged(0);
}

# FIXME: Missing doc
sub subscribe
{
    my ($self, $name, $password, $uuid, $mode) = @_;
    my $subscriptions = $self->subscriptionsResource($password);
    my $subscriptionCred = $subscriptions->subscribeServer($name, $uuid, $mode);

    my $state = $self->get_state();
    $state->{revokeAction} = {
        action => 'unsubscribe',
        params => [$subscriptionCred->{server_uuid}, $subscriptionCred->{password}]
    };
    $state->{just_subscribed} = 1;
    $self->set_state($state);

    # Mark webadmin as changed to reload composites + themes
    $self->global()->addModuleToPostSave('webadmin');

    $self->setSubscriptionCredentials($subscriptionCred);
    # Delete temporary stored password
    $self->unset('password');
    my $subscriptionInfo = $self->refreshSubscriptionInfo();
    return $subscriptionInfo;
}

# FIXME: Missing doc
sub unsubscribe
{
    my ($self, $password) = @_;

    # Check no other modules required to be subscribed
    EBox::RemoteServices::Subscription::Check::unsubscribeIsAllowed();

    if ($self->username() and $password) {
        my $subscriptions  = $self->subscriptionsResource($password);
        $subscriptions->unsubscribeServer();

        my $state = $self->get_state();
        my $cred  = $self->subscriptionCredentials();
        $state->{revokeAction} = {
            action => 'subscribe',
            params => [$cred->{name}, $cred->{subscription_uuid}, 'new',
                       $self->username(), $password
                      ]
           };
        $self->set_state($state);
    }

    $self->_removeSubscriptionData();

    # Mark webadmin as changed to reload composites + themes
    $self->global()->addModuleToPostSave('webadmin');
}

sub _removeSubscriptionData
{
    my ($self) = @_;
    $self->unset('username');
    $self->unset('subscription_credentials');
    $self->unset('subscription_info');
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
        $self->{rest} = $restRes->_restClientWithServerCredentials();
    }

    return $self->{rest};
}

# FIXME: Missing doc
# - userPassword is optional
sub subscriptionsResource
{
    my ($self, $userPassword) = @_;
    my $subscriptions = EBox::RemoteServices::RESTResource::Subscriptions->new(remoteservices => $self,
                                                                 userPassword   => $userPassword
                                                                );
    return $subscriptions;
}

# FIXME: Missing doc
sub confBackupResource
{
    my ($self) = @_;
    return EBox::RemoteServices::RESTResource::ConfBackup->new(remoteservices => $self);
}

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

# FIXME: Missing doc
sub authResource
{
    my ($self, $userPassword) = @_;
    return EBox::RemoteServices::RESTResource::Auth->new(remoteservices => $self,
                                           userPassword  => $userPassword);
}



# FIXME: Missing doc
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
#         business
#         enterprise
#         trial
#
sub subscriptionCodename
{
    my ($self, $force) = @_;

    $force = 0 unless defined($force);

    unless ($self->eBoxSubscribed()) {
        return '';
    }

    # TBD
    return 'professional';
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
    my ($self, $addOn, $force) = @_;

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

    my $state = $self->get_state();
    my $justSubscribed = delete $state->{just_subscribed};
    my $revokeAction = delete $state->{revokeAction};
    $self->set_state($state);

    my $alreadyChanged = $self->changed();
    my $subscriptionInfo = $self->refreshSubscriptionInfo();
    if ($self->changed() and not $alreadyChanged) {
        # changes due to subscription refresh
        $self->_saveConfig();
        $self->setAsChanged(0);
    }

    $self->setupSubscription($subscriptionInfo, $justSubscribed);

#    TODO: Disabled until reimplmented
#    $self->_setRemoteSupportAccessConf();

    $self->_updateMotd();
}

# Method: revokeConfig
#
#       Dismisses all changes done since the first write or delete operation.
#
sub revokeConfig
{
    my ($self) = @_;
    my $state = $self->get_state();
    my $revokeAction = delete $state->{revokeAction};
    $self->set_state($state);
    if ($revokeAction) {
        try {
            my $subscriptions = $self->subscriptionsResource();
            my $action = $revokeAction->{action};
            if ($action eq 'subscribe') {
                $subscriptions->subscribeServer(@{$revokeAction->{params}})
            } elsif ($action eq 'unsubscribe') {
                $subscriptions->unsubscribeServer(@{$revokeAction->{params}})
            } else {
                EBox::error("Unknown pending operation: $action. Skipping");
            }
        } catch ($ex) {
            EBox::error("Cannot undo " . $revokeAction->{action} . " operation. Please, undo it manually");
            $ex->throw();
        }
    }


    $self->SUPER::revokeConfig();
}


# FIXME: Missing doc
sub setupSubscription
{
    my ($self, $subscriptionInfo, $justSubscribed) = @_;

    $self->_setQAUpdates($subscriptionInfo);
    $self->_manageCloudProfPackage($subscriptionInfo);
    $self->_writeCronFile($subscriptionInfo);
}

sub _writeCronFile
{
    my ($self, $subscribed) = @_;

    if ($subscribed) {
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
            'core/zentyal-remoteservices.cron.mas',
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

    my $start = $subscriptionInfo->{subscription_start};
    my $end  = $subscriptionInfo->{subscription_end};
    if ((not $start) or (not $end)) {
        EBox::error("Subscription info has not either start or end date");
        return 0;
    }

    my ($sec,$min,$hour,$mday,$mon,$year) = gmtime();
    $year += 1900;
    $mon  += 1;
    # give one day margin
    if ($mday == 1) {
        if ($mon == 1) {
            $mon = 12;
            $year -= 1;
        } else {
            $mon = 1;
        }
        $mday = 31; # dont care for the comparation if it was a month with 30 days
    } else {
        $mday -= 1;
    }

    my $gmtime = sprintf('%04d-%02d-%02d %02d:%02d:%02d', $year, $mon, $mday, $hour, $min, $sec);
    return (($gmtime ge $start) and ($gmtime lt $end));
}

sub _manageCloudProfPackage
{
    my ($self, $subscriptionInfo) = @_;

    my $installed = $self->_pkgInstalled(PROF_PKG);
    if ((not $subscriptionInfo) or ($self->subscriptionLevel() < 1)) {
        unless ($installed) {
            $self->_downgrade();
        }
        return;
    }

    return if ($installed);

    $self->_installProfPkgs();
}

# TODO: reimplemnte
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
    # # TTT
    # if ($self->eBoxSubscribed() and $self->hasBundle()) {
    #     my $conn = new EBox::RemoteServices::Connection();
    #     my $vpnClient = $conn->vpnClient();
    #     if ($vpnClient) {
    #         EBox::RemoteServices::SupportAccess->setClientRouteUp($supportAccess, $vpnClient);
    #     }
    # }
    EBox::Sudo::root(EBox::Config::scripts() . 'sudoers-friendly');
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


#TTT
sub securityUpdatesAddOn
{
    # TODO: Remove calls to this method from other modules
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

# Method: _setQAUpdates
#
#       Turn the QA Updates ON or OFF depending on the subscription level
#
sub _setQAUpdates
{
    my ($self, $subscriptionInfo) = @_;
    my $qaUpdates = EBox::RemoteServices::QAUpdates->new($self);
    $qaUpdates->set($subscriptionInfo);

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
        return $self->addOnDetails('cloudusers', $force)->{max_users};
    }
    return 0;
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


    # TODO: commented until reimplement
    # $folder->add(new EBox::Menu::Item(
    #     'url'  => 'RemoteServices/Composite/Technical',
    #     'text' => __('Technical Support'),
    #    ));


    $root->add($folder);
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

    my ($serverName, $edition, $DRValue) =
      ( __('None'), '', __('Disabled'));

    my $supportValue = __x('Disabled - {oh}Enable{ch}',
                           oh => '<a href="/RemoteServices/Composite/Technical">',
                           ch => '</a>');

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

    }

    $section->add(new EBox::Dashboard::Value(__('Server name'), $serverName));

    $section->add(new EBox::Dashboard::Value(__('Server edition'),
                                             $edition));
    $section->add(new EBox::Dashboard::Value(__('Technical support'),
                                             $supportValue));
    $section->add(new EBox::Dashboard::Value(__s('Configuration backup'),
                                             $DRValue));
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
    my @pkgs = (PROF_PKG, SYNC_PKG);
    @pkgs = grep { $self->_pkgInstalled($_) } @pkgs;

    return unless ( @pkgs > 0 );

    my $fh = new File::Temp(DIR => EBox::Config::tmp());
    $fh->unlink_on_destroy(0);
    print $fh 'exec ' . REMOVE_PKG_SCRIPT . ' ' . join(' ', @pkgs) . "\n";
    close($fh);

    try {
        EBox::Sudo::command('at -f "' . $fh->filename() . '" now+1hour');
    } catch (EBox::Exceptions::Command $e) {
        EBox::debug($e->stringify());
    }
}

1;
