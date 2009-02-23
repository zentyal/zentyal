# Copyright (C) 2008 Warp Networks S.L.
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
# This class is the model to subscribe an eBox to the remote services
# offered. The following elements are required:
#
#     - user (volatile)
#     - password (volatile)
#     - common name
#
# The model has itself two states:
#
#     - eBox not subscribed. Default state. Prior an eBox subscription
#
#     - eBox subscribed. After an eBox subscription
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
use EBox::Types::Password;
use EBox::Types::Text;
use EBox::Validate;

# Core modules
use Error qw(:try);

# Constants
use constant {
    EBOX_SERVICES_URL => 'https://www.ebox-services.com',
    MAX_LENGTH => 20,
};

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

# Method: validatedTypedRow
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    if ( exists($changedFields->{eboxCommonName}) ) {
        my $cn = $changedFields->{eboxCommonName}->value();
        # Check if this does not contain underscores
        unless (EBox::Validate::checkDomainName($cn) and length($cn) < MAX_LENGTH) {
            throw EBox::Exceptions::InvalidData( data => $changedFields->{eboxCommonName}->printableName(),
                                                 value => $cn);
        }
    }

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
            EBox::RemoteServices::Backup->new()->cleanDaemons();
            $subsServ->deleteData($paramsRef->{eboxCommonName}->value());
        } else {
            # Subscribing
            my $subsData = $subsServ->subscribeEBox($paramsRef->{eboxCommonName}->value());
            # Indicate if the necessary to wait for a second or not
            if ( $subsData->{new} ) {
                $self->{returnedMsg} = __('Subscription was done correctly. Wait a minute to let '
                                          . 'the subscription be propagated throughout the system');
            } else {
                $self->{returnedMsg} = __('Subscription data retrieved correctly');
            }
        }
    }
    $self->_manageEvents(not $subs);

    # Call the parent method to store data in GConf and such
    $self->SUPER::setTypedRow($id, $paramsRef, %optParams);

    # Mark RemoteServices module as changed
    $self->{gconfmodule}->setAsChanged();

    $self->{gconfmodule}->st_set_bool('subscribed', not $subs);

    my $modManager = EBox::Model::ModelManager->instance();
    $modManager->markAsChanged();

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
            EBox::warn("Impossible to establish the connection to the name server. Firewall is not restarted yet");
        };
    }

}

# Method: eBoxSubscribed
#
#      Check if the current eBox is subscribed or not
#
# Returns:
#
#      boolean - indicating if the eBox is subscribed or not
#
sub eBoxSubscribed
{
    my ($self) = @_;

    my $subs = $self->{gconfmodule}->st_get_bool('subscribed');
    $subs = 0 if not defined($subs);
    return $subs;

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
    my $global = EBox::Global->getInstance();
    if ( $global->modExists('openvpn') ) {
        my $vpn = $global->modInstance('openvpn');
        return (not $global->modIsChanged('openvpn')
                  and $vpn->isEnabled());
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
    return __('Prior to make a subscription on remote services, '
              . 'enable the OpenVPN module and save or discard '
              . 'its changes');
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

    my @tableDesc =
      (
       new EBox::Types::Text(
                             fieldName     => 'username',
                             printableName => __('User name'),
                             editable      => (not $self->eBoxSubscribed()),
                             volatile      => 1,
                             acquirer      => \&_acquireFromGConfState,
                             storer        => \&_storeInGConfState,
                             ),
       new EBox::Types::Text(
                             fieldName      => 'eboxCommonName',
                             printableName  => __('eBox common name'),
                             editable       => (not $self->eBoxSubscribed()),
                             volatile       => 1,
                             acquirer       => \&_acquireFromGConfState,
                             storer         => \&_storeInGConfState,
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
        $printableTableName = __('eBox subscription details');
        $actionName = __('Delete data');
    } else {
        splice(@tableDesc, 1, 0, $passType);
        $printableTableName = __('Subscription to remote services');
        $actionName = __('Subscribe');
    }

    my $dataForm = {
                    tableName          => 'Subscription',
                    printableTableName => $printableTableName,
                    modelDomain        => 'RemoteServices',
                    defaultActions     => [ 'editField', 'changeView' ],
                    tableDescription   => \@tableDesc,
                    class              => 'dataForm',
                    help               => __x('In order to subscribe an eBox '
                                              . 'remote services {url}. '
                                              . 'You will have remote backup '
                                              . 'facilities and much more',
                                              url => EBOX_SERVICES_URL),
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

    my $model = $type->model();
    my $gconfmod = EBox::Global->modInstance('remoteservices');
    my $keyField = $model->name() . '/' . $type->fieldName();
    $type->{'value'} = $gconfmod->st_get_string($keyField);

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
    if ( $subscribing ) {
        $eventMod->enableService(1);
    }
    my $model = $eventMod->configureDispatcherModel();
    my $rowId = $model->findId( eventDispatcher => 'EBox::Event::Dispatcher::ControlCenter' );
    $model->setTypedRow($rowId, {}, readOnly => not $subscribing);
    $eventMod->enableDispatcher('EBox::Event::Dispatcher::ControlCenter',
                                $subscribing);

}

1;

