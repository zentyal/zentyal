# Copyright (C) 2010-2013 Zentyal
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

package EBox::RemoteServices::Model::RemoteSupportAccess;

use base 'EBox::Model::DataForm';

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::RemoteServices::SupportAccess;
use EBox::Exceptions::External;

# Constants

# Group: Public methods

# Constructor: new
#
#     Create the access settings form
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Returns:
#
#     <EBox::RemoteServices::Model::AccessSettings>
#
sub new
{

    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless ( $self, $class);

    return $self;

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
       new EBox::Types::Boolean(
                                fieldName     => 'allowRemote',
                                printableName => __('Allow remote access to Zentyal support'),
                                editable      => 1,
                                default       => 0,
                                help          => __('Allow Zentyal support engineers to connect '
                                                    . 'to your server from Zentyal Remote network.'),
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'fromAnyAddress',
                                printableName => __('Allow access from the Internet'),
                                editable      => 1,
                                default       => 0,
                                help          => __('Allow Zentyal support engineers to connect '
                                                    . 'to your server directly from the Internet '
                                                    . 'to your public IP address. Only use this '
                                                    . 'option if you could not connect to Zentyal Remote.'),
                               ),
      );

    my $dataForm = {
                    tableName          => __PACKAGE__->nameFromClass(),
                    printableTableName => __('Enable Remote Support Access'),
                    modelDomain        => 'RemoteServices',
                    defaultActions     => [ 'editField', 'changeView' ],
                    tableDescription   => \@tableDesc,
                    class              => 'dataForm',
                    help               => _message(),
                };

      return $dataForm;

}

# Method: validateTypedRow
#
#      Check the following:
#
#        - The remote access from any address is not only enabled when
#          the remote access is also enabled
#
#        - To enable simple remote support, you must be subscribed to
#          Zentyal Cloud
#
#        - To enable from any address remote support, the connection
#          with Zentyal Cloud must not exist
#
sub validateTypedRow
{
    my ($self, $actions, $params_r, $actual_r) = @_;
    if (exists $params_r->{allowRemote}) {
        if ($params_r->{allowRemote}->value()) {
            EBox::RemoteServices::SupportAccess->userCheck();
        }
    }

    my $access = exists $params_r->{allowRemote} ?
                        $params_r->{allowRemote}->value() :
                        $actual_r->{allowRemote}->value();
    my $fromAny = exists $params_r->{fromAnyAddress} ?
                        $params_r->{fromAnyAddress}->value() :
                        $actual_r->{fromAnyAddress}->value();

    my $rs = EBox::Global->modInstance('remoteservices');
    if ($fromAny) {
        if (not $access) {
            throw EBox::Exceptions::External(
__('Remote access from any address requires that remote access support is enabled')
                                            );
        }
        if ( $rs->isConnected() ) {
            throw EBox::Exceptions::External(
                __x('To allow any address remote support, you must not be connected '
                   . 'to {cloud}', cloud => 'Zentyal Remote')
               );
        }
    } else {
        if ($access) {
            if (not $rs->eBoxSubscribed()) {
            throw EBox::Exceptions::External(
__('To restrict addresses you need that your Zentyal Server is registered to Zentyal Remote. Either register it or allow access from any address')
                                            );
            }
        }
    }
}

sub _message
{
    my $msg =  __x(
 "Enabling remote support will allow Zentyal staff to freely access your computer.\n" .
 "You could use the 'screen' command to join their shell option. To allow that, the SUID bit of the 'screen' program is enabled. This change is undone when this option is disabled\n" .
 q[To join the remote session, login in the shell as a user belonging to the 'adm' group and use the command: '{cmd}'.],
   cmd => 'screen -x ebox-remote-support/'
    );
    return $msg;
}

sub viewCustomizer
{
    my ($self) = @_;

    my $sshWarning = $self->_sshWarningMessage();
    if ($sshWarning) {
        my $customizer = new EBox::View::Customizer();
        $customizer->setModel($self);
        $customizer->setPermanentMessage($sshWarning);
        return $customizer;
    }

    return $self->SUPER::viewCustomizer();
}

sub _sshWarningMessage
{
    my $msg;
    my @ssh = @{ EBox::RemoteServices::SupportAccess->sshListening };

    if (not @ssh) {
        return __('No running ssh daemon instance found.  Support access need a running instance to allow remote connections.');
    }

    @ssh = grep { $_->{address} eq '0.0.0.0'; } @ssh;
    if (not @ssh) {
        return __('Not ssh daemon instance listening on all interfaces found. Support access need a ssh daemon whom listens on all interfaces.');
    }

    my @noStandardPorts = map { $_->{port} != 22 ? ($_->{port}) : () }  @ssh;
    if (@noStandardPorts == @ssh) {
        return __x('ssh daemon found listening on non-standard port(s): {p}. Make sure to notify support which port(s) are used by ssh daemon.',
                   p => join (', ', @noStandardPorts)
                  );
    }

    return undef;
}

1;
