# Copyright (C) 2012-2013 Zentyal S.L.
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

# Class: EBox::Users::Model::Master
#
#   From to configure a Zentyal master to provide users to this server

use strict;
use warnings;

package EBox::Users::Model::Master;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Host;
use EBox::Types::Port;
use EBox::Types::Boolean;
use EBox::Types::Password;
use EBox::Exceptions::DataInUse;
use EBox::View::Customizer;

use constant VIEW_CUSTOMIZER => {
    none     => { hide => [ 'host', 'port', 'password' ] },
    zentyal  => { show => [ 'host', 'port', 'password' ] },
    cloud    => { hide => [ 'host', 'port', 'password' ] },
};

# Group: Public methods

# Constructor: new
#
#      Create a data form
#
# Overrides:
#
#      <EBox::Model::DataForm::new>
#
sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless( $self, $class );

    return $self;
}

# Method: _table
#
#	Overrides <EBox::Model::DataForm::_table to change its name
#
sub _table
{

    my ($self) = @_;

    # TODO make all this elements non-editable after change
    # (add a destroy button, to unregister from the master)

    my $master_options = [
        { value => 'none', printableValue => __('None') },
        { value => 'zentyal', printableValue => __('Other Zentyal Server') },

    ];

    if (EBox::Global->modExists('remoteservices')) {
        my $rs = EBox::Global->modInstance('remoteservices');
        if ($rs->usersSyncAvailable('force')) {
            push ($master_options,
                { value => 'cloud', printableValue  => __('Zentyal Cloud') }
            );
        }
    }

    my $unlocked = sub {
        return $self->_unlocked();
    };
    my $locked = sub {
        return $self->_locked();
    };

    my @tableDesc = (
        new EBox::Types::Select (
            fieldName => 'master',
            printableName => __('Sync users from'),
            options => $master_options,
            help => __('Sync users from the chosen source'),
            editable => 1,
        ),
        new EBox::Types::Host (
            fieldName => 'host',
            printableName => __('Master host'),
            editable => $unlocked,
            help => __('Hostname or IP of the master'),
        ),
        new EBox::Types::Port (
            fieldName => 'port',
            printableName => __('Master port'),
            defaultValue => 443,
            editable => $unlocked,
            help => __('Master port for Zentyal Administration (default: 443)'),
        ),
        new EBox::Types::Password (
            fieldName => 'password',
            printableName => __('Slave password'),
            editable => $unlocked,
            hidden => $locked,
            help => __('Password for new slave connection'),
        ),
    );

    my $dataForm = {
        tableName           => 'Master',
        printableTableName  => __('Sync users from a master server'),
        defaultActions      => [ 'editField', 'changeView' ],
        tableDescription    => \@tableDesc,
        modelDomain         => 'Users',
        help                => __('Configure this parameters to synchronize users from a master server'),
    };

    return $dataForm;
}

sub precondition
{
    my ($self) = @_;
    my $usersMod = $self->parentModule();
    return $usersMod->mode() eq $usersMod->STANDALONE_MODE();
}

# Method: viewCustomizer
#
#    Hide/show master options if Zentyal as master is configured
#
# Overrides:
#
#    <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    $customizer->setOnChangeActions( { master => VIEW_CUSTOMIZER } );
    return $customizer;
}

sub _locked
{
    my ($self) = @_;

    my $usersMod = $self->parentModule();
    my $master = $usersMod->get_hash('Master/keys/form');
    return (defined($master) and $master->{master} eq 'zentyal');
}

sub _unlocked
{
    my ($self) = @_;
    return (not $self->_locked());
}

sub validateTypedRow
{
    my ($self, $action, $changedParams, $allParams, $force) = @_;

    my $master = exists $allParams->{master} ?
                        $allParams->{master}->value() :
                        $changedParams->{master}->value();

    my $enabled = ($master ne 'none');

    # do not check if disabled
    return unless ($enabled);

    if ($master ne 'cloud') {
        $self->_checkSamba();
    }

    my $usersMod = $self->parentModule();

    # will the operation destroy current users?
    my $destroy = 1;

    if ($master eq 'zentyal') {
        # Check master is accesible
        my $host = exists $allParams->{host} ?
                          $allParams->{host}->value() :
                          $changedParams->{host}->value();

        my $port = exists $allParams->{port} ?
                          $allParams->{port}->value() :
                          $changedParams->{port}->value();

        my $password = exists $allParams->{password} ?
                              $allParams->{password}->value() :
                              $changedParams->{password}->value();

        $usersMod->masterConf->checkMaster($host, $port, $password);
    }

    if ($master eq 'cloud') {
        my $rs = new EBox::Global->modInstance('remoteservices');
        my $rest = $rs->REST();
        my $res = $rest->GET("/v1/users/realm/")->data();
        my $realm = $res->{realm};

        # If cloud is already provisoned destroy local users before sync
        $destroy = 0 if (not $realm);

        if ($realm and ($usersMod->kerberosRealm() ne $realm)) {
            throw EBox::Exceptions::External(__x('Master server has a different REALM, check hostnames. Master is {master} and this server {slave}.',
                master => $realm,
                slave => $usersMod->kerberosRealm()
            ));
        }

        my $realUsers = $usersMod->realUsers();
        $realUsers = scalar(@{$realUsers});
        my $max = $rs->maxCloudUsers('force');
        if ($max and $realUsers > $max) {
            my $current = $realUsers;
            throw EBox::Exceptions::External(__x('Your Zentyal Cloud allows a maximum of {max} users. Currently there are {current} users created.', current => $current, max => $max));
        }
    }

    my @ldapMods = grep {
        my $mod = $_;
        ($mod->name() ne $usersMod->name()) and
         ($mod->isa('EBox::LdapModule'))
    } @{ $self->global->modInstances() };

    unless ($force) {
        my $warnMsg = '';
        my $nUsers = scalar @{$usersMod->users()};
        if ($nUsers > 0 and $destroy) {
            $warnMsg = (__('CAUTION: this will delete all defined users and import master ones.'));
        }

        foreach my $mod (@ldapMods) {
            my $modWarn = $mod->slaveSetupWarning($master);
            if ($modWarn) {
                $warnMsg .= '<br/>' if $warnMsg;
                $warnMsg .= $modWarn;
            }
        }

        if ($warnMsg) {
            throw EBox::Exceptions::DataInUse($warnMsg);
        }
    }

    foreach my $mod (@ldapMods) {
        $mod->preSlaveSetup($master);
    }

    # set webAdmin as changed
    my $webAdminMod = EBox::Global->modInstance('webadmin');
    $webAdminMod->setAsChanged();
}

sub _checkSamba
{
    my $samba = EBox::Global->modInstance('samba');
    if (not $samba) {
        return;
    }
    if ($samba->configured()) {
        throw EBox::Exceptions::External(__('Cannot synchronize users with other Zentyal if Samba is either in use or provisioned'));
    }
}

sub master
{
    my ($self) = @_;
    my $master =  $self->row()->elementByName('master')->value();
    if ($master eq 'cloud') {
        my $remoteServices = $self->global()->modInstance('remoteservices');
        if (not $remoteServices) {
            return 'none';
        }

        return $remoteServices->eBoxSubscribed() ? 'cloud' : 'none';
    }

    return $master;
}

1;
