# Copyright (C) 2012 eBox Technologies S.L.
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
use EBox::Types::Host;
use EBox::Types::Port;
use EBox::Types::Boolean;
use EBox::Types::Password;
use EBox::Exceptions::DataInUse;

use strict;
use warnings;

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

    my @tableDesc = (
        new EBox::Types::Boolean (
            fieldName => 'enabled',
            printableName => __('Enabled'),
            defaultValue => 0,
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


sub _locked
{
    my $users = EBox::Global->modInstance('users');
    return $users->get('Master/enabled');
}

sub _unlocked
{
    return (not _locked());
}

sub validateTypedRow
{
    my ($self, $action, $changedParams, $allParams, $force) = @_;


    my $enabled = exists $allParams->{enabled} ?
                         $allParams->{enabled}->value() :
                         $changedParams->{enabled}->value();

    # do not check if disabled
    return unless ($enabled);

    my $host = exists $allParams->{host} ?
                      $allParams->{host}->value() :
                      $changedParams->{host}->value();

    my $port = exists $allParams->{port} ?
                      $allParams->{port}->value() :
                      $changedParams->{port}->value();

    my $password = exists $allParams->{password} ?
                          $allParams->{password}->value() :
                          $changedParams->{password}->value();


    # Check master is accesible
    my $users = EBox::Global->modInstance('users');
    $users->master->checkMaster($host, $port, $password);

    unless ($force) {
        my $prevEnabled = exists $changedParams->{enabled} ?
            not $enabled :
            $enabled;

        my $nUsers = scalar @{$users->users()};
        if ($enabled and not $prevEnabled and $nUsers > 0) {
            throw EBox::Exceptions::DataInUse(__('CAUTION: this will delete all defined users and import master ones.'));
        }
    }
}


1;
