# Copyright (C) 2008-2011 eBox Technologies S.L.
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

# Class: EBox::RemoteServices::Model::Subscription
#
# This class is the model to subscribe a Zentyal to the remote services
# offered. The following elements are required:
#
#     - user (volatile)
#     - password (volatile)
#     - common name
#
# The model has itself two states:
#
#     - Zentyal not subscribed. Default state. Prior to a Zentyal subscription
#
#     - Zentyal subscribed. After a Zentyal subscription
#

package EBox::RemoteServices::Model::Subscription;

use strict;
use warnings;

use base 'EBox::Model::DataForm';

use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Global;
use EBox::Model::ModelManager;
use EBox::RemoteServices::Backup;
use EBox::RemoteServices::Subscription;
use EBox::RemoteServices::Configuration;
use EBox::RemoteServices::Types::EBoxCommonName;
use EBox::Types::Password;
use EBox::Types::Text;
use EBox::Validate;
use EBox::View::Customizer;

# Core modules
use Error qw(:try);
use Sys::Hostname;

use constant STORE_URL => 'http://store.zentyal.com/';
use constant UTM       => '?utm_source=zentyal&utm_medium=ebox&utm_content=remoteservices'
                          . '&utm_campaign=register';
use constant PROF_URL  => STORE_URL . 'serversubscriptions/subscription-professional.html' . UTM;
use constant ENTER_URL => STORE_URL . 'serversubscriptions/subscription-enterprise.html' . UTM;

# Group: Public methods

# Constructor: new
#
#     Create the subscription form
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Returns:
#
#     <EBox::RemoteServices::Model::Subscription>
#
sub new
{

    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless ( $self, $class);

    return $self;

}

# Method: setTypedRow
#
# Overrides:
#
#      <EBox::Model::DataTable::setTypedRow>
#
sub setTypedRow
{
    my ($self, $id, $paramsRef, %optParams) = @_;

    my $subs = $self->eBoxSubscribed();

    # Check the user, password and common name are
    my $correctParams = 0;
    if ( $subs ) {
        $correctParams = ( defined($paramsRef->{username}) and defined($paramsRef->{eboxCommonName}));
        $correctParams = $correctParams
          and ( $paramsRef->{username}->value() and $paramsRef->{eboxCommonName}->value());
    } else {
        $correctParams = ( defined($paramsRef->{username}) and defined($paramsRef->{password})
                           and defined($paramsRef->{eboxCommonName}));
        $correctParams = $correctParams and ( $paramsRef->{username}->value()
                                              and $paramsRef->{password}->value()
                                              and $paramsRef->{eboxCommonName}->value()
                                             );
    }

    if ( $correctParams ) {
        # Password is not defined or yes
        my $password = '';
        $password = $paramsRef->{password}->value() if defined($paramsRef->{password});
        my $subsServ = EBox::RemoteServices::Subscription->new(user => $paramsRef->{username}->value(),
                                                               password => $password);
        if ( $subs ) {
            # Desubscribing
            EBox::RemoteServices::Subscription::checkUnsubscribeIsAllowed();
            EBox::RemoteServices::Backup->new()->cleanDaemons();
            $subsServ->deleteData($paramsRef->{eboxCommonName}->value());
        } else {
            # Subscribing
            my $subsData = $subsServ->subscribeEBox($paramsRef->{eboxCommonName}->value());
            # Indicate if the necessary to wait for a second or not
            if ( $subsData->{new} ) {
                $self->{returnedMsg} = __('Subscription was done correctly. Save changes and then, '
                                          . 'wait a minute to guarantee the system carries out '
                                          . 'the process of subscribing. Later you can start '
                                          . 'using the cloud based services you are entitled '
                                          . 'to with your subscription (remote backup, updates, alerts, etc.)');
            } else {
                $self->{returnedMsg} = __('Subscription data retrieved correctly.');
            }
            $self->{returnedMsg} .= ' ' . __('Please, save changes');
            $self->{gconfmodule}->st_set_bool('just_subscribed', 1);
        }
    }
    $self->_manageEvents(not $subs);
    $self->_manageMonitor(not $subs);
    $self->_manageLogs(not $subs);
    $self->_manageSquid(not $subs);

    # Call the parent method to store data in our conf storage
    $self->SUPER::setTypedRow($id, $paramsRef, %optParams);

    # Mark RemoteServices module as changed
    $self->{gconfmodule}->setAsChanged();

    $self->{gconfmodule}->st_set_bool('subscribed', not $subs);

    my $modManager = EBox::Model::ModelManager->instance();
    $modManager->markAsChanged();

    # Mark the apache module as changed as well
    my $apacheMod = EBox::Global->modInstance('apache');
    $apacheMod->setAsChanged();

    # Reload table
    $self->reloadTable();

    # Return the message
    if ( $self->{returnedMsg} ) {
        $self->setMessage($self->{returnedMsg});
        $self->{returnedMsg} = '';
    } else {
        $self->setMessage(__('Done'));
    }

    if ( not $subs ) {
        try {
            # Establish VPN connection after subscribing and store data in backend
            EBox::RemoteServices::Backup->new()->connection();
        } catch EBox::Exceptions::External with {
            EBox::warn('Impossible to establish the connection to the name server. Firewall is not restarted yet');
        };
    }

}

# Method: eBoxSubscribed
#
#      Check if the current Zentyal is subscribed or not
#
# Returns:
#
#      boolean - indicating if the Zentyal is subscribed or not
#
sub eBoxSubscribed
{
    my ($self) = @_;

    my $subs = $self->{gconfmodule}->st_get_bool('subscribed');
    $subs = 0 if not defined($subs);
    return $subs;
}

# Method: unsubscribe
#
#      Delete every data related to the Zentyal subscription and stop any
#      related service associated with it
#
# Returns:
#
#      True  - if Zentyal is subscribed and now it is not
#
#      False - if Zentyal was not subscribed before
#
sub unsubscribe
{
    my ($self) = @_;

    if ($self->eBoxSubscribed()) {
        EBox::RemoteServices::Subscription::checkUnsubscribeIsAllowed();

        my $row = $self->row();

        # Storing again make subscription if it is already done and
        # unsubscribing if Zentyal is subscribed
        $row->store();
        return 1;
    } else {
        return 0;
    }
}

# Method: viewCustomizer
#
#      Return a custom view customizer to set a permanent message if
#      the VPN is not enabled or configured
#
# Overrides:
#
#      <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    if ( $self->{gconfmodule}->subscriptionLevel() < 1) {
        $customizer->setPermanentMessage($self->_commercialMsg());
    }
    return $customizer;
}

# Method: help
#
# Overrides:
#
#      <EBox::Model::DataTable::help>
#
sub help
{
    my ($self) = @_;

    my $msg = '';
    if (not $self->eBoxSubscribed()) {
        $msg = __s('To subscribe your Zentyal Server to Zentyal Cloud, you need to get first one of the Server Subscriptions (Basic, Professional or Enterprise) from the Zentyal On-line Store. Once you have obtained one of these subscriptions, you will be sent a user name and password you can use below to subscribe your server to Zentyal Cloud.');
        $msg .= '<br/><br/>';

        #my $modChanges = $self->_modulesToChange();
        #if (exists $modChanges->{configure}) {
        #    $msg .= __x(
        #        'Subscribing Zentyal will configure the {mods} and its dependencies ',
        #        mods =>  $modChanges->{configure},
        #       );
        #}

        #if (exists $modChanges->{enable}) {
        #    $msg .= __x('Subscribing Zentyal will enable the {mods} and its dependencies.<br/>',
        #                mods => $modChanges->{enable}
        #              );
        #}

        $msg .= __('Take into account that subscribing your Zentyal server to the Zentyal Cloud can take a while. Please do not touch anything until the subscription process is correctly finished.');
    }

    return $msg;
}

# Method: precondition
#
#       Only allowed when the openvpn is saved its changes
#
# Overrides:
#
#      <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;
    my $global = EBox::Global->getInstance();
    if ( $global->modExists('openvpn') ) {
        my $changed = $global->modIsChanged('openvpn');
        if ($changed) {
            return 0;
        } else {
            return 1;
        }
    } else {
        return 0;
    }
}

# Method: preconditionFailMsg
#
#       Only allowed when the openvpn is saved its changes
#
# Overrides:
#
#      <EBox::Model::DataTable::preconditionFailMsg>
#
sub preconditionFailMsg
{
    my ($self) = @_;
    return __('Prior to make a subscription on remote services, '
              . 'save or discard changes in the OpenVPN module');
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataForm::_table>
#
sub _table
{
    my ($self) = @_;

    my $hostname = Sys::Hostname::hostname();
    ($hostname) = split( /\./, $hostname); # Remove the latest part of
                                           # the hostname to make it a
                                           # valid subdomain name

    my @tableDesc =
      (
       new EBox::Types::Text(
                             fieldName     => 'username',
                             printableName => __('User Name or Email Address'),
                             editable      => (not $self->eBoxSubscribed()),
                             volatile      => 1,
                             acquirer      => \&_acquireFromGConfState,
                             storer        => \&_storeInGConfState,
                             ),
       new EBox::RemoteServices::Types::EBoxCommonName(
                             fieldName      => 'eboxCommonName',
                             printableName  => __('Server Name'),
                             editable       => (not $self->eBoxSubscribed()),
                             volatile       => 1,
                             acquirer       => \&_acquireFromGConfState,
                             storer         => \&_storeInGConfState,
                             help           => __('Choose a name for your server which is '
                                                  . 'a valid subdomain name'),
                             defaultValue   => $hostname,
                            ),
      );

    my $passType = new EBox::Types::Password(
        fieldName     => 'password',
        printableName => __('Password'),
        editable      => 1,
        volatile      => 1,
        storer        => \&_emptyFunc,
       );

    my ($actionName, $printableTableName);
    if ( $self->eBoxSubscribed() ) {
        $printableTableName = __('Zentyal subscription details');
        $actionName = __('Unsubscribe');
    } else {
        splice(@tableDesc, 1, 0, $passType);
        $printableTableName = __('Subscription to Zentyal Cloud');
        $actionName = __('Subscribe');
    }

    my $dataForm = {
                    tableName          => 'Subscription',
                    printableTableName => $printableTableName,
                    modelDomain        => 'RemoteServices',
                    defaultActions     => [ 'editField', 'changeView' ],
                    tableDescription   => \@tableDesc,
                    printableActionName => $actionName,
                   };

    return $dataForm;
}

# Group: Private methods

sub _emptyFunc
{

}

# Only applicable to text types
sub _acquireFromGConfState
{
    my ($type) = @_;

    my $model    = $type->model();
    my $gconfmod = EBox::Global->modInstance('remoteservices');
    my $keyField = $model->name() . '/' . $type->fieldName();
    my $value    = $gconfmod->st_get_string($keyField);
    if ( defined($value) and ($value ne '') ) {
        return $value;
    }

    return undef;

}

# Only applicable to text types, whose value is store in GConf state
sub _storeInGConfState
{
    my ($type, $gconfModule, $directory) = @_;

    my $keyField = "$directory/" . $type->fieldName();
    if ( $type->memValue() ) {
        $gconfModule->st_set_string($keyField, $type->memValue());
    } else {
        $gconfModule->st_unset($keyField);
    }
}

# Manage the event control center dispatcher and events module
# depending on the subcription
sub _manageEvents # (subscribing)
{
    my ($self, $subscribing) = @_;

    my $eventMod = EBox::Global->modInstance('events');
    if ( $subscribing )  {
        # events is always configured but we left this code just in case the
        # module changes
        $self->_configureAndEnable($eventMod);

    }
    my $model = $eventMod->configureDispatcherModel();
    my $rowId = $model->findId( eventDispatcher => 'EBox::Event::Dispatcher::ControlCenter' );
    $model->setTypedRow($rowId, {}, readOnly => not $subscribing);
    $eventMod->enableDispatcher('EBox::Event::Dispatcher::ControlCenter',
                                $subscribing);

}

sub _manageMonitor
{
    my ($self, $subscribing) = @_;

    my $monitorMod = EBox::Global->modInstance('monitor');
    if ( $subscribing )  {
        $self->_configureAndEnable($monitorMod);
    }
}

sub _manageLogs
{
    my ($self, $subscribing) = @_;

    my $logsMod = EBox::Global->modInstance('logs');
    if ( $subscribing )  {
        $self->_configureAndEnable($logsMod);
    }
}

# Manage ebox-squid, if installed, to be marked as changed
sub _manageSquid
{
    my ($self, $subscribing) = @_;

    # It does change the behaviour depending if subscribing/unsubscribing
    my $gl = EBox::Global->getInstance();
    if ( $gl->modExists('squid') ) {
        my $squidMod = $gl->modInstance('squid');
        if ( $squidMod->isEnabled() ) {
            $squidMod->setAsChanged();
        }
    }

}


sub _configureAndEnable
{
    my ($self, $mod) = @_;

    if (not $mod->configured) {
        $mod->setConfigured(1);
        $mod->enableActions();
    }
    if (not $mod->isEnabled()) {
        $mod->enableService(1);
    }
}

sub _modulesToChange
{
    my ($self) = @_;

    my %toChange = ();

    my @configure;
    my @enable;

    my @mods = qw(openvpn events monitor logs);
    foreach my $modName (@mods) {
        my $mod =  EBox::Global->modInstance($modName);
        $mod or next; # better error control here by now just skipping
        if (not $mod->configured()) {
            push @configure, $mod->printableName();
        } elsif (not $mod->isEnabled()) {
            push @enable, $mod->printableName();
        }
    }

    if (@enable) {
        $toChange{enable} = _modListToHumanStr(\@enable);
    }

    if (@configure) {
        $toChange{configure} = _modListToHumanStr(\@configure);
    }

    return \%toChange;
}

sub _modListToHumanStr
{
    my ($list) = @_;
    my @list = @{ $list };
    if (@list == 1) {
        return $list[0] . __( ' module');
    }

    my $str;
    my $last = pop @list;
    $str = join ', '. @list;
    $str = $str . __(' and ') . $last . __(' modules');
    return $str;
}


# Dump the module actions string
sub _actionsStr
{
    my ($self, $mod) = @_;

    my $gl = EBox::Global->getInstance();

    my $retStr = '';
    foreach my $depName ((@{$mod->depends()}, $mod->name())) {
        my $depMod = $gl->modInstance($depName);
        unless ( $depMod->configured() ) {
            foreach my $action (@{$mod->actions()}) {
                $retStr .= __('Action') . ':' . $action->{action} . '<br/>';
                $retStr .= __('Reason') . ':' . $action->{reason} . '<br/>';
            }
        }
    }

    return $retStr;
}

# Dump the module actions string
sub _filesStr
{
    my ($self, $mod) = @_;

    my $gl = EBox::Global->getInstance();

    my $retStr = '';
    foreach my $depName ((@{$mod->depends()}, $mod->name())) {
        my $depMod = $gl->modInstance($depName);
        unless ( $depMod->configured() ) {
            foreach my $file (@{$mod->usedFiles()}) {
                $retStr .= __('File') . ':' . $file->{file} . '<br/>';
                $retStr .= __('Reason') . ':' . $file->{reason} . '<br/>';
            }
        }
    }
    return $retStr;
}

# Return the commercial message
sub _commercialMsg
{
    return __sx('For full, enterprise-level services, obtain '
                . '{openhrefp}Professional{closehref} or '
                . '{openhrefe}Enterprise Server Subscription{closehref} - '
                . 'These offer Quality Assured software updates, Alerts, '
                . 'Reports and Centralised monitoring and management of your '
                . 'Zentyal servers!',
                openhrefp  => '<a href="' . PROF_URL . '" target="_blank">',
                openhrefe => '<a href="' . ENTER_URL . '" target="_blank">',
                closehref => '</a>');
}

1;

