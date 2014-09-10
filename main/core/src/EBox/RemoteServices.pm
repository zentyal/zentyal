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

package EBox::RemoteServices;

use base qw(EBox::Module::Config);

# Class: EBox::RemoteServices
#
#      RemoteServices module to handle everything related to the remote
#      services offered
#

# no warnings 'experimental::smartmatch';
# use feature qw(switch);

use EBox::Sudo;
use EBox::Util::Version;
use EBox::Validate;
use EBox::WebAdmin::PSGI;
use TryCatch::Lite;
use File::Slurp;
use JSON::XS;
use Net::DNS;
use POSIX;
use YAML::XS;

use EBox::Gettext;
use EBox::Global;

use EBox::Exceptions::External;
use EBox::Exceptions::Internal;

use EBox::RemoteServices::Subscriptions;
use EBox::RemoteServices::ConfBackup;
use EBox::RemoteServices::Auth;
use EBox::RemoteServices::QAUpdates;

use EBox::Menu::Folder;
use EBox::Menu::Item;

use constant SUBSCRIPTION_LEVEL_NONE => -1;
use constant CRON_FILE           => '/etc/cron.d/zentyal-remoteservices';


# use Data::UUID;
#use Date::Calc;
# use EBox::Config;
# use EBox::Dashboard::ModuleStatus;
# use EBox::Dashboard::Section;
# use EBox::Dashboard::Value;
# use EBox::DBEngineFactory;
# use EBox::Exceptions::DeprecatedMethod;

# 
# use EBox::Exceptions::MissingArgument;
# use EBox::Exceptions::NotConnected;
# use EBox::Event;
# use EBox::GlobalImpl;
# use EBox::Service;
# use EBox::RemoteServices::AdminPort;
# use EBox::RemoteServices::Audit::Password;
# use EBox::RemoteServices::Auth;
# use EBox::RemoteServices::Backup;
# use EBox::RemoteServices::Bundle;
# use EBox::RemoteServices::Capabilities;
# use EBox::RemoteServices::Connection;
# use EBox::RemoteServices::Configuration;
# use EBox::RemoteServices::Cred;
# use EBox::RemoteServices::Exceptions::NotCapable;

# use EBox::RemoteServices::SupportAccess;
# use EBox::RemoteServices::FirewallHelper;
# use EBox::RemoteServices::RESTClient;
# use EBox::RemoteServices::QAUpdates;


# # Constants
# use constant SERV_DIR            => EBox::Config::conf() . 'remoteservices/';
# use constant SUBS_DIR            => SERV_DIR . 'subscription/';
# use constant WS_DISPATCHER       => __PACKAGE__ . '::WSDispatcher';
# use constant RUNNERD_SERVICE     => 'ebox.runnerd';
# use constant REPORTERD_SERVICE   => 'zentyal.reporterd';
# use constant COMPANY_KEY         => 'subscribedHostname';
# use constant RELEASE_UPGRADE_MOTD => '/etc/update-motd.d/91-release-upgrade';
# use constant REDIR_CONF_FILE     => EBox::Config::etc() . 'remoteservices_redirections.yaml';
# use constant DEFAULT_REMOTE_SITE => 'remote.zentyal.com';

# # OCS conf constants
# use constant OCS_CONF_FILE       => '/etc/ocsinventory/ocsinventory-agent.cfg';
# use constant OCS_CONF_MAS_FILE   => 'remoteservices/ocsinventory-agent.cfg.mas';
# use constant OCS_CRON_FILE       => '/etc/cron.daily/ocsinventory-agent';
# use constant OCS_CRON_MAS_FILE   => 'remoteservices/ocsinventory-agent.cron.mas';

use constant RELEASE_UPGRADE_MOTD => '/etc/update-motd.d/91-release-upgrade';

my %i18nLevels = ( '-1' => __('Unknown'),
                   '0'  => __('Community'),
                   '5'  => __('Small Business'),
                   '6'  => __('Professional'),
                   '7'  => __('Business'),
                   '8'  => __('Enterprise Trial'),
                   '10' => __('Enterprise'),
                   '20' => __('Premium'));


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

    if (defined ($version)) {
        # Upgrading...
        if ($self->eBoxSubscribed()) {
            # Restart the service
            unless (-e '/var/lib/zentyal/tmp/upgrade-from-CC') {
                $self->restartService();
            }
        }
    }

# TODO see if this continues to make sense
#    EBox::Sudo::root('chown -R ebox:adm ' . EBox::Config::conf() . 'remoteservices');
}


# Method: isEnabled
#
#       Module is always emabled
#
# Overrides:
#
#       <EBox::Module::Service::isEnabled>
#
sub isEnabled
{
    my ($self) = @_;
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
    my ($self) = @_;
    my $info = $self->subscriptionInfo();
    # TODO TEMPORALLY
    if ((not $info)) {
        return SUBSCRIPTION_LEVEL_NONE; 
    } 
    return 1;
    # END TEMPORALLY
    
    if ((not $info) or (not $info->{'level'})) {
        return SUBSCRIPTION_LEVEL_NONE; 
    } 

    return $info->{'level'};
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
sub password
{
    my ($self) = @_;
    $self->get('password');
}

# FIXME: Missing doc
sub setUsername
{
    my ($self, $username) = @_;
        # TODO vladiate
    if (not $username) {
        throw EBox::Exceptions::External('username');
    }
    $self->set('username', $username);
}

# FIXME: Missing doc
sub setPassword
{
    my ($self, $password) = @_;
    # TODO VLAIDATE
    if (not $password) {
        throw EBox::Exceptions::External('password');
    }
    $self->set('password', $password);
}

# FIXME: Missing doc
sub refreshSubscriptionInfo
{
    my ($self) = @_;
    my $subscriptionInfo;
    try {
        my $subscriptions = $self->subscriptionsResource();
        $subscriptionInfo = $subscriptions->subscriptionInfo();
    } catch ($ex) {
        EBox::warn("Cannot refresh subscription information, using cached data: $ex");
        $subscriptionInfo = $self->subscriptionInfo();
    }

    if (not $subscriptionInfo) {
        $self->unsubscribe();
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

# FIXME: Missing doc
sub subscriptionInfo
{
    my ($self) = @_;
    $self->get('subscription_info');
}

# FIXME: Missing doc
sub setSubscriptionCredentials
{
    my ($self, $cred) = @_;
    $self->set('subscription_credentials', $cred);
}

# FIXME: Missing doc
sub subscriptionCredentials
{
    my ($self) = @_;
    $self->get('subscription_credentials');
}

# FIXME: Missing doc
sub subscribe 
{
    my ($self, $name, $uuid, $mode) = @_;
    my $subscriptions = $self->subscriptionsResource();
    my $subscriptionCred = $subscriptions->subscribeServer($name, $uuid, $mode);
    
    my $state = $self->get_state();
    $state->{revokeAction} = {
        action => 'unsubscribe',
        params => [$subscriptionCred->{server_uuid}, $subscriptionCred->{password}]
    };
    $self->set_state($state);

    $self->setSubscriptionCredentials($subscriptionCred);
    my $subscriptionInfo = $self->refreshSubscriptionInfo();
    return $subscriptionInfo;
}

# FIXME: Missing doc
sub unsubscribe
{
    my ($self) = @_;
    my $subscriptions  = $self->subscriptionsResource();
    $subscriptions->unsubscribeServer();

    my $state = $self->get_state();
    my $cred  = $self->subscriptionCredentials();
    $state->{revokeAction} = {
        action => 'subscribe',
        params => [$cred->{name}, $cred->{subscription_uuid}, 'new',
                   $self->username(), $self->password()
                  ]
    };
    $self->set_state($state);

    $self->_removeSubscriptionData();
}

sub _removeSubscriptionData
{
    my ($self) = @_;
    $self->unset('username');
    $self->unset('password');
    $self->unset('subscription_credentials');
    $self->unset('subscription_info');
}

# FIXME: Missing doc
sub subscriptionsResource
{
    my ($self) = @_;
    my $subscriptions = EBox::RemoteServices::Subscriptions->new(remoteservices => $self);
    return $subscriptions;
}

# FIXME: Missing doc
sub confBackupResource
{
    my ($self) = @_;
    return EBox::RemoteServices::ConfBackup->new(remoteservices => $self);
}

# FIXME: Missing doc
sub authResource
{
    my ($self) = @_;
    return EBox::RemoteServices::Auth->new(remoteservices => $self);
}



# FIXME: Missing doc
sub eBoxSubscribed
{
    my ($self) = @_;
    my $level = $self->subscriptionLevel();
    return ($level != SUBSCRIPTION_LEVEL_NONE);
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

# FIXME: Missing doc
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

# FIXME: Missing doc
sub _setConf
{
    my ($self) = @_;

    my $state = $self->get_state();
    my $revokeAction = delete $state->{revokeAction};
    $self->set_state($state);

    my $alreadyChanged = $self->changed();
    my $subscriptionInfo = $self->refreshSubscriptionInfo();
    if ($self->changed() and not $alreadyChanged) {
        # changes due to subscription refresh
        $self->_saveConfig();
        $self->setAsChanged(0);
    }

    $self->setupSubscription($subscriptionInfo);

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
    my ($self, $subscriptionInfo) = @_;
    if ($subscriptionInfo and $self->_checkSubscriptionAlive($subscriptionInfo)) {
        $subscriptionInfo = undef;
    }

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
            $self->st_set_list('rand_mins' , 'int',  \@randMins);
            $hours = \@randHours;
        }

        my $mins = $self->get_list('rand_mins');

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

    my @gmtParts = gmtime();
    @gmtParts = map {
        if ($_ == 0) {
            ('00');
        } elsif ($_ < 10) {
            ('0' . $_ )
        } else {
            ($_)
        }
    } @gmtParts;
    my ($sec,$min,$hour,$mday,$mon,$year) = @gmtParts;
    my $gmtime = "$year-$mon-$mday $hour:$min:$sec";
    return (($gmtime ge $start) and ($gmtime lt $end));
}

sub _manageCloudProfPackage
{
    my ($self, $subscriptionInfo) = @_;
    my $pkgName = 'zentyal-cloud-prof';
    if ((not $subscriptionInfo) or ($subscriptionInfo->{level} < 1)) {
        system "dpkg -l $pkgName";
        if ($? == 0 ) {
            try {
                EBox::Sudo::root("dpkg -r $pkgName");
            } catch ($ex) {
                EBox::error("Error removing package $pkgName: $ex");
            }
        }
        return;
    } 

    try {
        EBox::Sudo::root("apt-get update");
    } catch($ex) {
        EBox::error("Ignoring list update error: $ex");
    }

    try {
        EBox::Sudo::root("apt-get install -y --force-yes $pkgName");
    } catch($ex){
        EBox::error("Error installing package $pkgName: $ex");
    }
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
#    Check if we have to remove any ad message
#
sub checkAdMessages
{
    my ($self) = @_;
    # TTT
    return;

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


#TTT
sub securityUpdatesAddOn
{
    return 0;
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
    return 0;
    # TTT
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
    # TTT where get users?
    return 0;
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

    $folder->add(new EBox::Menu::Item('url'  => 'RemoteServices/Index',
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
            'title'   => __('Your Zentyal Server Account'),
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

    my ($serverName, $fqdn, $connValue, $connValueType, $subsLevelValue, $DRValue) =
      ( __('None'), '', '', 'info', '', __('Disabled'));

    my $ASUValue = __x('Disabled - {oh}Enable{ch}',
                       oh => '<a href="/RemoteServices/View/AdvancedSecurityUpdates">',
                       ch => '</a>');
    my $supportValue = __x('Disabled - {oh}Enable{ch}',
                           oh => '<a href="/RemoteServices/Composite/Technical">',
                           ch => '</a>');

    if ( $self->eBoxSubscribed() ) {
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
        $subsLevelValue = __sx('None - {oh}Register for Free!{ch}',
                               oh => '<a href="/RemoteServices/Composite/General">',
                               ch => '</a>');
    }

    $section->add(new EBox::Dashboard::Value(__('Server name'), $serverName));

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




1;

__DATA__


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

    if ($force) {
    }
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
# XXX seemos 9only used by capabilities.pm
sub subscribedUUID
{
    my ($self) = @_;
#  "server_uuid"
    my $cred = $self->subscriptionCredentials();
    if ((not $cred or (not exists $cred->{server_uuid})) {
        throw EBox::Exceptions::External(
            __('The UUID is only available if the host is subscribed to Zentyal Remote')
           );
    }


    return $self->{server_uuid};;
}






1;
