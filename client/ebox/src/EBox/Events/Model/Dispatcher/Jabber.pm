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
use EBox::Global;
use EBox::Types::Boolean;
use EBox::Types::Int;
use EBox::Types::Password;
use EBox::Types::Text;
use EBox::Validate;

################
# Dependencies
################
use Net::Jabber::JID;

# Constants 
# use constant JABBER_DISPATCHER_SERVICE_NAME => 'Jabber dispatcher client';

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

      if ( exists ( $params->{server} )) {
          # We assume the Jabber domain should be a valid DNS domain
          EBox::Validate::checkDomainName( $params->{server}->value(),
                                           $params->{server}->printableName() );
      }

      if ( exists ( $params->{port} )) {
          EBox::Validate::checkPort( $params->{port}->value(),
                                     $params->{port}->printableName() );
      }

      # Check the JID
      if ( exists ( $params->{adminJID} )) {
          $self->_checkAdminJID( $params->{adminJID}->value() );
      }

  }

# Method: formSubmitted
#
#       When the form is submitted, the model must set up the jabber
#       dispatcher client service and sets the output rule in the
#       firewall
#
# Overrides:
#
#      <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
  {

      my ($self, $oldRow) = @_;

      my $gl = EBox::Global->getInstance();

#      if ( $gl->modExists('services')) {
#          my $servMod = $gl->modInstance('services');
#          my $method;
#          if ( $servMod->serviceExists('name' => JABBER_DISPATCHER_SERVICE_NAME)) {
#              $method = 'setService';
#          } else {
#              $method = 'addService';
#          }
#          $servMod->$method(name            => JABBER_DISPATCHER_SERVICE_NAME,
#                            protocol        => 'tcp',
#                            sourcePort      => 'any',
#                            destinationPort =>  $jabberServPort,
#                            internal        => 1,
#                            readOnly        => 1,
#                            # FIXME: Add backview parameter
#                            description     => __x('To be updated at {href}' .
#                                                   'Jabber dispatcher configuration' .
#                                                   '{endHref}',
#                                                  href => '<a href="/ebox/' . $self->menuNamespace() 
#                                                   . '?directory=' . $self->directory() . '">',
#                                                  endHref => '</a>'),
#                           );
          if ( $gl->modExists('firewall') ){
              my $fwMod = $gl->modInstance('firewall');
              my $jabberServPort = $self->portValue();
              $fwMod->removeOutputRule( 'tcp', $oldRow->valueByName('port'));
              $fwMod->addOutputRule( 'tcp', $jabberServPort);
#              my ( $idx, $row ) = ( 0, undef);
#              my $servId = $servMod->serviceId(JABBER_DISPATCHER_SERVICE_NAME);
#              do {
#                  $row = $fwMod->getOutputService( $idx );
#                  $idx++;
#                  if ( defined ( $row )) {
#                      last if ( $row->{plainValueHash}->{service} eq $servId );
#                  }
#              } while ( defined ( $row ));
#              if ( defined ( $row ) ) {
#                  # The rule already exists
#                  ;
#              } else {
#                  $fwMod->addOutputService( decision => 'accept',
#                                            destination => { destination_any => 'any',
#                                                             inverse => 0 },
#                                            service     => $servId,
#                                            description => 'Jabber dispatcher connection to a Jabber server');
#              }
#          }
          }


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
             help          => __('Jabber server to send the messages')
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
             help          => __('Jabber ID of the account ' .
                 'that will send the messages. ' .
                 'Hint: do not introduce @domain, only the user name')
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
             help           => __('Tick this option if ' .
                 'you want eBox to create an account for ' .
                 'the above user')
             ),

         new EBox::Types::Text(
             fieldName     => 'adminJID',
             printableName => __('Administrator Jabber Identifier'),
             size          => 12,
             editable      => 1,
             help          => __('Destination Jabber ID of the messages ' .
                'generated by eBox,  i.e: you, the eBox admin. Note ' .
                'that you need to register this  account manually in ' .
                'any jabber server')
             ),
        );

      my $dataForm = {
                      tableName          => 'JabberDispatcherForm',
                      printableTableName => __('Configure Jabber dispatcher'),
                      modelDomain        => 'Events',
                      defaultActions     => [ 'editField' ],
                      tableDescription   => \@tableDesc,
                      class              => 'dataForm',
                      help               => __('This dispatcher will send ' .
                                               'events to an Jabber account'),
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
