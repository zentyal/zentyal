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
# simple form with 2 fields:
#
#     - subject
#     - to
#
# The mail is sent using eBox mail SMTP.

package EBox::Mail::Model::Dispatcher::Mail;

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
        );

      my $dataForm = {
                      tableName          => 'MailDispatcherConfiguration',
                      printableTableName => __('Configure mail dispatcher'),
                      modelDomain        => 'Events',
                      defaultActions     => [ 'editField' ],
                      tableDescription   => \@tableDesc,
                      class              => 'dataForm',
                      help               => __('In order to configure the Mail event dispatcher '
                                               . 'is required to enable the mail service from eBox'),
                      messages           => {
                                             update => __('Mail dispatcher configuration updated'),
                                            },
                     };

      return $dataForm;

  }

# Group: Private methods

1;
