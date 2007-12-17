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

# Class: EBox::Events::Model::Dispatcher::Mail
#
# This class is the model to configurate the Mail dispatcher. It
# inherits from <EBox::Model::DataForm> since it is not a table but a
# simple form with 5 fields:
#
#     - subject
#     - to
#     - smtp
#     - port
#     - user
#     - pass
#

package EBox::Events::Model::Dispatcher::Mail;

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
# Core modules
################
use Sys::Hostname;

################
# Dependencies
################

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

      my ($self, $action, $changedFields) = @_;

      if ( exists ( $changedFields->{to} )) {
          EBox::Validate::checkEmailAddress( $changedFields->{to}->value(),
                                             $changedFields->{to}->printableName() );
      }

      if ( exists ( $changedFields->{smtp} )) {
          my $selectedField = $changedFields->{smtp}->selectedType();
          if ( $selectedField eq 'custom_smtp' ) {
              EBox::Validate::checkDomainName( $changedFields->{smtp}->value(),
                                               $changedFields->{smtp}->printableName() );
          }
      }


  }

# Method: formSubmitted
#
#       When the form is submitted, the model must set up the mail
#       dispatcher service and sets the output rule in the firewall
#
# Overrides:
#
#      <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
  {

      my ($self, $oldRow) = @_;

      my $gl = EBox::Global->getInstance();

      if ( $gl->modExists('firewall') ){
          my $smtpUnionType = $self->smtpType();
          if ( $smtpUnionType->selectedType() eq 'custom_smtp' ) {
              my $fwMod = $gl->modInstance('firewall');
              $fwMod->addOutputRule( 'tcp', '25');
          }
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

      # Just add the eBox SMTP server option when it's installed
      my @smtpSubTypes = ();
      my $gl = EBox::Global->getInstance();
      push(@smtpSubTypes, new EBox::Types::Text(
                                                fieldName     => 'custom_smtp',
                                                printableName => __('custom'),
                                                editable      => 1,
                                               ));
      push(@smtpSubTypes, new EBox::Types::Union::Text(
                                                       fieldName => 'eBoxSMTP',
                                                       printableName => __('local eBox'),
                                                       disabled => not $gl->modExists('mail'),
                                                      ));


      my @tableDesc =
        (
         new EBox::Types::Text(
                               fieldName        => 'subject',
                               printableName    => __('Subject'),
                               editable         => 1,
                               defaultValue     => __x('[EBox-event] An event has happened at {hostName}',
                                                       hostName => hostname()),
                               size             => 70,
                               allowUnsafeChars => 1,
                              ),
         new EBox::Types::Text(
                               fieldName     => 'to',
                               printableName => __('To'),
                               editable      => 1,
                              ),
         new EBox::Types::Union(
                                fieldName     => 'smtp',
                                printableName => __('Mail (SMTP) server'),
                                editable      => 1,
                                subtypes      => \@smtpSubTypes,
                               ),
         new EBox::Types::Text(
                               fieldName     => 'user',
                               printableName => __('User'),
                               editable      => 1,
                               optional      => 1,
                              ),
         new EBox::Types::Password(
                                   fieldName        => 'password',
                                   printableName    => __('User password'),
                                   editable         => 1,
                                   optional         => 1,
                                   size             => 6,
                                   allowUnsafeChars => 1,
                                  ),
        );

      my $dataForm = {
                      tableName          => 'MailDispatcherConfiguration',
                      printableTableName => __('Configure mail dispatcher'),
                      modelDomain        => 'Events',
                      defaultActions     => [ 'editField' ],
                      tableDescription   => \@tableDesc,
                      class              => 'dataForm',
                      help               => __('In order to configure the Mail event dispatcher '
                                               . 'is required to connect to a smarthost (SMTP or mail '
                                               . 'server). The server may require authentication. We '
                                               . 'try PLAIN, LOGIN with/without TLS automatically. '
                                               . 'User and password are optionals and depends on the '
                                               . 'required configuration by the mail server'),
                      messages           => {
                                             update => __('Mail dispatcher configuration updated'),
                                            },
                     };

      return $dataForm;

  }

# Group: Private methods

1;
