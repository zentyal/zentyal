# Copyright (C) 2010 eBox Technologies
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



package EBox::RemoteServices::Model::RemoteSupportAccess;

use strict;
use warnings;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::RemoteServices::SupportAccess;

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

# Method: validateTypedRow
#
#     Override to check the user to provide support exists
#
# Overrides:
#
#     <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $actions, $params) = @_;
    if (exists $params->{allowRemote}) {
        if ($params->{allowRemote}->value()) {
            EBox::RemoteServices::SupportAccess->userCheck();
        }
    }
}

# Method: viewCustomizer
#
#     Override to set the message to log in the screen session
#
# Overrides:
#
#     <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;
    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    $customizer->setPermanentMessage(_message());
    return $customizer;
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
                                printableName => __('Allow remote access to eBox staff'),
                                editable      => 1,
                                default       => 0,
                               ),
      );

    my $dataForm = {
                    tableName          => 'RemoteSupportAccess',
                    printableTableName => __('Remote support access configuration'),
                    modelDomain        => 'RemoteServices',
                    defaultActions     => [ 'editField', 'changeView' ],
                    tableDescription   => \@tableDesc,
                    class              => 'dataForm',
                    help               => _help(),
                    pageTitle          => __('Remote Support Access'),
                };

      return $dataForm;

  }

# Group: Private methods

sub _help
{
    return __x('eBox Technologies provides support for eBox Platform through our '
               . '{openhref}store{closehref}',
               openhref => '<a href="http://store.ebox-technologies.com?utm_source=ebox&utm_medium=ebox&utm_content=remoteaccess&utm_campaign=access"'
                           . ' target="_blank">',
               closehref => '</a>');
}

sub _message
{
    my $msg =  __x(
 q[To join the remote session, login in the shell as a user belonging to the '{group}' group and use the command '{cmd}'.],
   group => 'adm',
   cmd => 'screen -x ebox-remote-support/'
    );
    return $msg;
}


1;
