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

# Class: EBox::RemoteServices::Model::Subscription
#
# This class is the model to subscribe a Zentyal to the remote services
# offered. The following elements may be present:
#
#     - user (volatile)
#     - password (volatile)
#     - common name
#     - options (volatile and optional)
#
# The model has itself two states:
#
#     - Zentyal not subscribed. Default state. Prior to the registration
#
#     - Zentyal subscribed. After the registration
#

use strict;
use warnings;

package EBox::RemoteServices::Model::Subscription;

use base 'EBox::Model::DataForm';

use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Global;
use EBox::Model::Manager;
use EBox::RemoteServices::Backup;
use EBox::RemoteServices::Configuration;
use EBox::RemoteServices::Subscription;
use EBox::RemoteServices::Subscription::Check;
use EBox::RemoteServices::Types::EBoxCommonName;
use EBox::Types::Action;
use EBox::Types::Password;
use EBox::Types::Select;
use EBox::Types::Text;
use EBox::Validate;
use EBox::View::Customizer;

# Core modules
use TryCatch::Lite;
use Sys::Hostname;

my $subsWizardURL = '/Wizard?page=RemoteServices/Wizard/Subscription';

# Group: Public methods

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
        # Password is not defined when unsubscribing but it is when subscribing
        my $password = '';
        $password = $paramsRef->{password}->value() if defined($paramsRef->{password});
        my $subsServ = EBox::RemoteServices::Subscription->new(user => $paramsRef->{username}->value(),
                                                               password => $password);
        if ( $subs ) {
            # Desubscribing
            EBox::RemoteServices::Subscription::Check::unsubscribeIsAllowed();
            $subsServ->deleteData($paramsRef->{eboxCommonName}->value());
        } else {
            # Subscribing
            my $selectedOption = exists $paramsRef->{options} ? $paramsRef->{options}->value() : undef;
            my $subsData = $subsServ->subscribeServer($paramsRef->{eboxCommonName}->value(),
                                                      $selectedOption);
            # If several options are given, then we have to show them
            if ( $subsData->{availableEditions} ) {
                my $subOptions = { 'options' => $subsData->{availableEditions},
                                   'pass'    => $password };
                my $state = $self->parentModule()->get_state();
                $state->{sub_options} = $subOptions;
                $self->parentModule()->set_state($state);
                $self->SUPER::setTypedRow($id, $paramsRef, %optParams);
                $self->reloadTable();
                $self->setMessage(__('Select one of the available options'));
                return; # Come back to show the form again
            }
            # Indicate if the necessary to wait for a second or not
            if ( $subsData->{new} ) {
                $self->{returnedMsg} = __('Registration was done correctly. Wait a minute '
                                          . 'to guarantee the system carries out '
                                          . 'the process of registration. Later on, you can start '
                                          . 'using the cloud based services you are entitled '
                                          . 'to with your edition (remote backup, updates, alerts, etc.)');
            } else {
                $self->{returnedMsg} = __('Registration data retrieved correctly.');
            }

            $self->parentModule()->st_set_bool('just_subscribed', 1);
            $self->parentModule()->st_unset('sub_options');
        }
    }
    # Call the parent method to store data in our conf storage
    $self->SUPER::setTypedRow($id, $paramsRef, %optParams);

    # Mark RemoteServices module as changed
    $self->parentModule()->setAsChanged();

    $self->parentModule()->st_set_bool('subscribed', not $subs);

    $self->_manageEvents(not $subs);
    $self->_manageMonitor(not $subs);
    $self->_manageLogs(not $subs);
    $self->_manageSquid(not $subs);

    # Set DynDNS configuration
    $self->_setDDNSConf(not $subs);

    my $modManager = EBox::Model::Manager->instance();
    $modManager->markAsChanged();

    # Mark the webadmin module as changed as well
    my $webadminMod = EBox::Global->modInstance('webadmin');
    $webadminMod->setAsChanged();

    # Reload table
    $self->reloadTable();

    # Return the message
    if ( $self->{returnedMsg} ) {
        $self->setMessage($self->{returnedMsg});
        $self->{returnedMsg} = '';
    } else {
        $self->setMessage(__('Done'));
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

    my $subs = $self->parentModule()->st_get_bool('subscribed');
    $subs = 0 if not defined($subs);
    return $subs;
}

# Method: showAvailable
#
#      Check if we have options available to show them to the user
#
# Returns:
#
#      Boolean - indicating if there are options available or not
#
sub showAvailable
{
    my ($self) = @_;

    return exists $self->parentModule()->get_state()->{'sub_options'};
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
        EBox::RemoteServices::Subscription::Check::unsubscribeIsAllowed();

        my $row = $self->row();

        # Storing again make subscription if it is already done and
        # unsubscribing if Zentyal is subscribed
        $row->store();
        # clear cache
        $self->parentModule()->clearCache();

        return 1;
    } else {
        return 0;
    }
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
        $msg = __sx("Register your Zentyal Server to Zentyal's remote monitoring and management platform (Zentyal Remote) here. Get a {ohf}free account{ch} or use the credentials of your {oh}Commercial Edition{ch} for full access.",
            ohf => '<a href="/Wizard?page=RemoteServices/Wizard/Subscription">',
            oh => '<a href="' . EBox::Config::urlEditions() . '" target="_blank">', ch => '</a>');
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

        $msg .= __('Take into account that registering your Zentyal server to the Zentyal Remote can take a while. Please do not touch anything until the registration process is correctly finished.');
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
    return __('Prior to make a registration on remote services, '
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
    $hostname =~ s/_//g; # Remove underscores as they are not valid
                         # subdomain values although they are valid hostnames

    my $subscribed = $self->eBoxSubscribed();

    my @tableDesc =
      (
       new EBox::Types::Text(
                             fieldName     => 'username',
                             printableName => __('Registration Email Address'),
                             editable      => (not $subscribed),
                             volatile      => 1,
                             acquirer      => \&_acquireFromState,
                             storer        => \&_storeInConfigState,
                             ),
       new EBox::RemoteServices::Types::EBoxCommonName(
                             fieldName      => 'eboxCommonName',
                             printableName  => __('Server Name'),
                             editable       => (not $subscribed),
                             volatile       => 1,
                             acquirer       => \&_acquireFromState,
                             storer         => \&_storeInConfigState,
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
        acquirer      => \&_tempPasswd,
       );

    if ( $self->showAvailable() ) {
        push(@tableDesc,
             new EBox::Types::Select(fieldName     => 'options',
                                     printableName => __('Available Options'),
                                     populate      => \&_populateOptions,
                                     help          => __('Select one of your purchases'),
                                     editable      => 1,
                                     volatile      => 1,
                                     storer        => \&_emptyFunc));
    }

    my ($actionName, $printableTableName);
    my ($customActions, $defaultActions) = ([], []);
    if ( $self->eBoxSubscribed() ) {
        $printableTableName = __('Zentyal registration details');
        $actionName = __('Unregister');
        push(@{$customActions}, new EBox::Types::Action(
            model          => $self,
            name           => 'unsubscribe',
            printableValue => $actionName,
            onclick        => \&_subscribeAction,
           ));
    } else {
        splice(@tableDesc, 1, 0, $passType);
        $printableTableName = __('Register your Zentyal Server');
        $actionName = __('Register');
        push(@{$customActions}, new EBox::Types::Action(
            model          => $self,
            name           => 'subscribe',
            printableValue => $actionName,
            onclick        => \&_subscribeAction,
            template       => '/remoteservices/register_button.mas',
           ));
    }

    my $dataForm = {
                    tableName           => 'Subscription',
                    printableTableName  => $printableTableName,
                    modelDomain         => 'RemoteServices',
                    defaultActions      => $defaultActions,
                    customActions       => $customActions,
                    tableDescription    => \@tableDesc,
                    printableActionName => $actionName,
                    disableAutocomplete => 1,
                   };

    return $dataForm;
}

# Group: Private methods

sub _emptyFunc
{

}

# Only applicable to text types
sub _acquireFromState
{
    my ($type) = @_;

    my $model = $type->model();
    my $value = $model->parentModule()->get_state()->{$model->name()}->{$type->fieldName()};
    if ( defined($value) and ($value ne '') ) {
        return $value;
    }

    return undef;
}

# Only applicable to text types, whose value is store in state config
sub _storeInConfigState
{
    my ($type, $hash) = @_;

    my $model     = $type->model();
    my $module    = $model->parentModule();
    my $state     = $module->get_state();
    my $modelName = $model->name();
    my $keyField  = $type->fieldName();
    if ( $type->memValue() ) {
        $state->{$modelName}->{$keyField} = $type->memValue();
    } else {
        delete $state->{$modelName}->{$keyField};
    }
    $module->set_state($state)
}

# Store the password temporary when selecting the options
sub _tempPasswd
{
    my ($type) = @_;

    my $module = EBox::Global->instance()->modInstance('remoteservices');
    my $pass = undef;
    my $state = $module->get_state();
    if (exists $state->{'sub_options'}) {
        # Get the temporary stored password
        $pass = $state->{'sub_options'}->{pass};
    }
    return $pass;

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

    # Enable Cloud dispatcher only if enough subs level is available
    if ( (not $subscribing) or ($self->parentModule()->subscriptionLevel() >= 5) ) {
        my $model = $eventMod->model('ConfigureDispatchers');
        my $rowId = $model->findId(dispatcher => 'EBox::Event::Dispatcher::ControlCenter');
        $model->setTypedRow($rowId, {}, readOnly => not $subscribing);
        $eventMod->enableDispatcher('EBox::Event::Dispatcher::ControlCenter',
                                    $subscribing);
    }

    if ($subscribing) {
        try {
            # Enable software updates alert
            # Read-only feature depends on subscription level
            $eventMod->enableWatcher('EBox::Event::Watcher::Updates', $subscribing );
        } catch (EBox::Exceptions::DataNotFound $e) {
            # Ignore when the event watcher is not there
        }
    }
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

# Manage zentyal-squid, if installed, to be marked as changed
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
        EBox::debug('Configuring ' . $mod->name());
        $mod->setConfigured(1);
        $mod->enableActions();
    }
    if (not $mod->isEnabled()) {
        EBox::debug('Enabling ' . $mod->name());
        $mod->enableService(1);
    }
}

# Set the Dynamic DNS configuration only if the service was not
# enabled before and using other method
sub _setDDNSConf
{
    my ($self, $subscribing) = @_;

    my $networkMod = EBox::Global->modInstance('network');
    my $ddnsModel = $networkMod->model('DynDNS');
    if ( $subscribing ) {
        unless ( $networkMod->isDDNSEnabled() ) {
            $ddnsModel->set(enableDDNS => 1,
                            service    => 'cloud');
        } else {
            EBox::info('DynDNS is already in used, so not using Zentyal Remote service');
        }
    } elsif ( $networkMod->DDNSUsingCloud() ) {
        $ddnsModel->set(enableDDNS => 0);
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

# Populate the available options from the cloud
sub _populateOptions
{
    my $rs = EBox::Global->instance()->modInstance('remoteservices');

    my $options = $rs->get_state()->{'sub_options'};
    $options = $options->{options};

    my @options = map { { value          => $_->{id},
                          printableValue => $_->{server} ? __x('Use existing server from {c}', c => $_->{company} )
                                                          :  $_->{company} . ' : ' . $_->{name} } }
      @{$options};

    # Filter out the repetitive values
    my %seen = ();
    my @r = ();
    foreach my $e (@options) {
        unless ( $seen{$e->{printableValue}} ) {
            push(@r, $e);
            $seen{$e->{printableValue}} = 1;
        }
    }
    @options = @r;

    # Option to reload the available options
    push(@options, { value => 'reload', printableValue => __('Reload available options')});
    return \@options;
}

# Show save changes JS code
sub _subscribeAction
{
    my ($self, $id) = @_;

    # FIXME: force parameter in DataTable::fields method
    undef $self->{fields};
    my $fields        = $self->fields();
    my $fieldsArrayJS = '[' . join(', ', map { "'$_'" } @{$fields}) . ']';
    my $tableName     = $self->name();
    my $subscribed    = $self->eBoxSubscribed() ? 'true' : 'false';
    my $caption       = ($subscribed eq 'true') ? __('Unregistering a server') : __('Registering a server');

    # Simulate changeRow but showing modal box on success
    my $jsStr = <<JS;
      var url =  '/RemoteServices/Controller/Subscription';
      Zentyal.TableHelper.cleanMessage('$tableName');
      Zentyal.TableHelper.setLoading('customActions_${tableName}_submit_form', '$tableName', true);
       \$.ajax({
                      url: url,
                      type: 'get',
                      data: 'action=edit&tablename=$tableName&directory=$tableName&id=form&' +  Zentyal.TableHelper.encodeFields('$tableName', $fieldsArrayJS ),
                      dataType: 'json',
                      success: function(response) {
                           if (!response.success) {
                                  Zentyal.TableHelper.setError('$tableName', response.error);
                                  Zentyal.TableHelper.restoreHidden('customActions_${tableName}_submit_form', '$tableName');
                                 return;
                           }

                           Zentyal.TableHelper.changeView(url, '$tableName', '$tableName', 'changeList');
                           Zentyal.TableHelper.setMessage('$tableName', response.msg);
                           if ( document.getElementById('${tableName}_password') == null || $subscribed ) {
                               Zentyal.Dialog.showURL('/RemoteServices/Subscription', {
                                                       title: '$caption',
                                                       showCloseButton: false,
                                                       close: function() { window.location.reload(); }
                                                     });
                           } else {
                                Zentyal.refreshSaveChangesButton();
                           }
                      },
                      error : function(t) {
                            Zentyal.TableHelper.setError('$tableName', t.responseText);
                            Zentyal.TableHelper.restoreHidden('customActions_${tableName}_submit_form', '$tableName');
                            Zentyal.refreshSaveChangesButton();
                      }
                  });

return false
JS
    return $jsStr;
}

1;
