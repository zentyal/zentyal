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

# Class: EBox::UsersAndGroups::Model::Master
#
#   From to configure a Zentyal master to provide users to this server

package EBox::UsersAndGroups::Model::Master;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Host;
use EBox::Types::Port;
use EBox::Types::Boolean;
use EBox::Types::Password;
use EBox::Exceptions::DataInUse;
use EBox::View::Customizer;

use strict;
use warnings;


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
            editable => \&_unlocked,
            help => __('Hostname or IP of the master'),
        ),
        new EBox::Types::Port (
            fieldName => 'port',
            printableName => __('Master port'),
            defaultValue => 443,
            editable => \&_unlocked,
            help => __('Master port for Zentyal Administration (default: 443)'),
        ),
        new EBox::Types::Password (
            fieldName => 'password',
            printableName => __('Slave password'),
            editable => \&_unlocked,
            hidden => \&_locked,
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
    my $users = EBox::Global->modInstance('users');
    my $master = $users->get_hash('Master/keys/form');
    return (defined($master) and $master->{master} eq 'zentyal');
}

sub _unlocked
{
    return (not _locked());
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

    my $users = EBox::Global->modInstance('users');

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

        $users->masterConf->checkMaster($host, $port, $password);
    }

    if ($master eq 'cloud') {
        my $rs = new EBox::Global->modInstance('remoteservices');
        my $rest = $rs->REST();
        my $res = $rest->GET("/v1/users/realm/")->data();
        my $realm = $res->{realm};

        # If cloud is already provisoned destroy local users before sync
        $destroy = 0 if (not $realm);

        if ($realm and ($users->kerberosRealm() ne $realm)) {
            throw EBox::Exceptions::External(__x('Master server has a different REALM, check hostnames. Master is {master} and this server {slave}.',
                master => $realm,
                slave => $users->kerberosRealm()
            ));
        }

        my $realUsers = $users->realUsers('without_admin');
        $realUsers = scalar(@{$realUsers});
        my $max = $rs->maxCloudUsers('force');
        if ($max and $realUsers > $max) {
            my $current = $realUsers;
            throw EBox::Exceptions::External(__x('Your Zentyal Cloud allows a maximum of {max} users. Currently there are {current} users created.', current => $current, max => $max));
        }
    }

    my @ldapMods = grep {
        my $mod = $_;
        ($mod->name() ne $users->name()) and
         ($mod->isa('EBox::LdapModule'))
    } @{ $self->global->modInstances() };

    unless ($force) {
        my $warnMsg = '';
        my $nUsers = scalar @{$users->users()};
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

    # set apache as changed
    my $apache = EBox::Global->modInstance('apache');
    $apache->setAsChanged();
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

1;
