# Copyright (C) 2009-2013 Zentyal S.L.
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

use strict;
use warnings;

package EBox::Asterisk::Model::Voicemail;

use base 'EBox::Model::DataForm';

# Class: EBox::Asterisk::Model::Voicemail
#
#      Form to change the user Voicemail settings in the UserCorner
#

use EBox::Gettext;
use EBox::Types::Password;
use EBox::Types::MailAddress;
use EBox::Types::Boolean;
use Apache2::RequestUtil;

use EBox::AsteriskLdapUser;

# Group: Public methods

# Constructor: new
#
#       Create the new Voicemail model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Asterisk::Model::Voicemail> - the recently created model
#
sub new
{
   my $class = shift;

   my $self = $class->SUPER::new(@_);

   bless($self, $class);

   return $self;
}

# Method: pageTitle
#
#      Get the i18ned name of the page where the model is contained, if any
#
# Overrides:
#
#      <EBox::Model::DataForm::pageTitle>
#
# Returns:
#
#      string
#
sub pageTitle
{
    return __('Voicemail settings');
}

# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader =
    (
        new EBox::Types::Password(
            fieldName     => 'pass',
            printableName => __('New password'),
            size          => '4',
            unique        => 1,
            editable      => 1
        ),
        new EBox::Types::MailAddress(
            fieldName     => 'mail',
            printableName => __('Mail address'),
            size          => '14',
            unique        => 1,
            editable      => 1
        ),
        new EBox::Types::Boolean(
            fieldName     => 'attach',
            printableName => __('Attach messages'),
            editable      => 1,
            defaultValue  => 0,
        ),
        new EBox::Types::Boolean(
            fieldName     => 'delete',
            printableName => __('Delete sent messages'),
            editable      => 1,
            defaultValue  => 0,
        ),
    );
    my $dataTable =
    {
        tableName          => 'Voicemail',
        printableTableName => __('Voicemail settings'),
        defaultActions     => ['editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataForm',
        help               => __('Change your Voicemail settings'),
        modelDomain        => 'Asterisk',
    };

    return $dataTable;
}

# Method: row
#
#       Return the row reading data from LDAP.
#
# Overrides:
#
#       <EBox::Model::DataForm::row>
#
sub row
{
    my ($self) = @_;

    my $usersMod = EBox::Global->modInstance('users');
    my $ldap = $usersMod->ldap();

    my $request = Apache2::RequestUtil->request();
    my $username = $request->user();
    my $user = $usersMod->userByUID($username);

    my $pass = $user->get('AstVoicemailPassword');
    my $mail = $user->get('AstVoicemailEmail');
    my $attach = $user->get('AstVoicemailAttach');
    my $delete = $user->get('AstVoicemailDelete');

    my $row = $self->_setValueRow(pass   => $pass,
                                  mail   => $mail,
                                  attach => $attach eq 'yes',
                                  delete => $delete eq 'yes');

    # dummy id for dataform
    $row->setId('dummy');

    return $row;
}

# Method: _addTypedRow
#
# Overrides:
#
#       <EBox::Model::DataForm::_addTypedRow>
#
sub _addTypedRow
{
    my ($self, $paramsRef, %optParams) = @_;

    my $pass = $paramsRef->{'pass'}->value();
    my $mail = $paramsRef->{'mail'}->value();
    my $attach;
    if ($paramsRef->{'attach'}->value()) {
       $attach = 'yes';
    } else {
       $attach = 'no';
    }
    my $delete;
    if ($paramsRef->{'delete'}->value()) {
       $delete = 'yes';
    } else {
       $delete = 'no';
    }

    my $usersMod = EBox::Global->modInstance('users');
    my $ldap = $usersMod->ldap();

    my $request = Apache2::RequestUtil->request();
    my $username = $request->user();
    my $user = $usersMod->userByUID($username);

    $user->set('AstVoicemailPassword', $pass, 1);
    $user->set('AstVoicemailEmail', $mail, 1);
    $user->set('AstVoicemailAttach', $attach, 1);
    $user->set('AstVoicemailDelete', $delete, 1);
    $user->save();

    $self->setMessage(__('Settings successfully updated.'));
}

sub precondition
{
    my ($self) = @_;
    my $request = Apache2::RequestUtil->request();
    my $username = $request->user();
    my $usersMod = EBox::Global->modInstance('users');
    my $user = $usersMod->usersByUID($username);

    my $userLdap = EBox::AsteriskLdapUser->new();
    return $userLdap->hasAccount($user);
}

sub preconditionFailMsg
{
    return __('You have not an VoIP account. Maybe VoIP is not enabled in this server.');
}

1;
