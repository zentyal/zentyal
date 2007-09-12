# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::Events::Model::Dispatcher::Jabber
#
# This class is the model to configurate Jabber dispatcher. It
# inherits from <EBox::Model::DataForm> since it is not a table but a
# simple form with four fields:
#
#     - server
#     - port
#     - user
#     - password
#     - subscribe
#     - adminJID
#

package EBox::Events::Model::Dispatcher::Jabber;

use base 'EBox::Model::DataForm';

# eBox uses
use EBox::Exceptions::InvalidData;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Int;
use EBox::Types::Password;
use EBox::Types::Text;
use EBox::Validate;

################
# Dependencies
################
use Net::Jabber::JID;

# Group: Public methods

# Constructor: new
#
#     Create the configure jabber dispatcher form
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Returns:
#
#     <EBox::Event::Dispatcher::Model::Jabber>
#
sub new
  {
      my $class = shift;

      my $self = $class->SUPER::new(@_);
      bless ( $self, $class);

      return $self;

  }

# Method: validateTypedRow
#
#
# Overrides:
#
#     <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
  {

      my ($self, $action, $params) = @_;

      # We assume the Jabber domain should be a valid DNS domain
      EBox::Validate::checkDomainName( $params->{server}->value(),
                                       $params->{server}->printableName() );
      EBox::Validate::checkPort( $params->{port}->value(),
                                 $params->{port}->printableName() );
      # Check the JID
      $self->_checkAdminJID( $params->{adminJID}->value() );

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

      my @tableDesc =
        (
         new EBox::Types::Text(
                               fieldName     => 'server',
                               printableName => __('Jabber server name'),
                               size          => 12,
                               editable      => 1,
                              ),
         new EBox::Types::Int(
                              fieldName     => 'port',
                              printableName => __('Port'),
                              size          => 6,
                              editable      => 1,
                              defaultValue  => 5222,
                             ),
         new EBox::Types::Text(
                               fieldName     => 'user',
                               printableName => __('Jabber user name'),
                               size          => 12,
                               editable      => 1,
                              ),
         new EBox::Types::Password(
                                   fieldName     => 'password',
                                   printableName => __('User password'),
                                   size          => 12,
                                   editable      => 1,
                                   minLength     => 4,
                                   maxLength     => 25,
                                  ),
         new EBox::Types::Boolean(
                                  fieldName      => 'subscribe',
                                  printableName  => __('Subscribe'),
                                  editable       => 1,
                                 ),
         new EBox::Types::Text(
                               fieldName     => 'adminJID',
                               printableName => __('Administrator Jabber Identifier'),
                               size          => 12,
                               editable      => 1,
                              ),
        );

      my $dataForm = {
                      tableName          => 'JabberDispatcherForm',
                      printableTableName => __('Configure Jabber dispatcher'),
                      modelDomain        => 'Events',
                      defaultActions     => [ 'editField' ],
                      tableDescription   => \@tableDesc,
                      class              => 'dataForm',
                      help               => __('In order to configure the Jabber event dispatcher ' .
                                               'is required to be registered at the chosen Jabber ' .
                                               'server or check subscribe to do register. The administrator ' .
                                               'identifier should follow the pattern: user@domain[/resource]'),
                      messages           => {
                                             update => __('Jabber dispatcher configuration updated'),
                                            },
                     };

      return $dataForm;

  }

# Group: Private methods

# Check the admin JID
sub _checkAdminJID # (jid)
  {

      my ($self, $adminJID) = @_;

      my $jid = new Net::Jabber::JID();
      $jid->SetJID($adminJID);

      # Both userID and server must not be empty
      unless ( $jid->GetUserID() and $jid->GetServer() ) {
          # Some changes was needed
          throw EBox::Exceptions::InvalidData( data => __('Administrator Jabber Identifier'),
                                               value => $adminJID,
                                               advice => __('It should follow the pattern ' .
                                                            q{'user@domain[/resource]'})
                                             );
      }

  }

1;
