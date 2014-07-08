# Copyright (C) 2010-2014 Zentyal S.L.
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

package EBox::Mail::Model::ExternalAccounts;
use base 'EBox::Model::DataTable';

#
#  To manage email retrieval form external accounts in the user corner
#  section
#

use EBox;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Global;
use EBox::Types::Host;
use EBox::Types::MailAddress;
use EBox::Types::Password;
use EBox::Types::Port;
use EBox::Types::Select;
use EBox::Samba::User;
use EBox::Validate;

sub new
{
   my $class = shift;

   my $self = $class->SUPER::new(@_);
   $self->{mailMod} = EBox::Global->modInstance('mail');

   bless($self, $class);

   return $self;
}

sub precondition
{
    my ($self) = @_;

    my $usercornerMod = EBox::Global->modInstance('usercorner');
    unless (defined $usercornerMod) {
        $self->{preconditionFail} = 'notUserCorner';
        return undef;
    }

    unless ($usercornerMod->editableMode()) {
        $self->{preconditionFail} = 'nonEditableMode';
        return undef;
    }

    unless (defined $self->_userAccount()) {
        $self->{preconditionFail} = 'notEmailAccount';
        return undef;
    }

    return 1;
}

sub preconditionFailMsg
{
    my ($self) = @_;

    if ($self->{preconditionFail} eq 'notUserCorner') {
        return __('This form is only available from the User Corner application.');
    }
    if ($self->{preconditionFail} eq 'nonEditableMode') {
        return __('Password change is only available in master or standalone servers. You need to change your password from the user corner of your master server.');
    }
    if ($self->{preconditionFail} eq 'notEmailAccount') {
        return __('Cannot retrieve mail from external accounts because you do not have a email account in a local mail domain');
    }
}

# Method: pageTitle
#
#      Get the i18ned name of the page where the model is contained, if any
#
# Overrides:
#
#      <EBox::Model::DataTable::pageTitle>
#
# Returns:
#
#      string
#
sub pageTitle
{
    return __('External mail accounts');
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
        new EBox::Types::Text(
            fieldName     => 'externalAccount',
            printableName => __('External account'),
            size          => '14',
            unique        => 1,
            editable      => 1
        ),
        new EBox::Types::Password(
            fieldName     => 'password',
            printableName => __('Password'),
            size          => '14',
            unique        => 0,
            editable      => 1
        ),
        new EBox::Types::Host(
            fieldName => 'server',
            printableName => __('Mail server'),
            editable => 1,
           ),
        new EBox::Types::Select(
            fieldName => 'protocol',
            printableName => ('Protocol'),
            populate      => \&_mailProtocols,
            editable => 1,
           ),
        new EBox::Types::Port(
            fieldName => 'port',
            printableName => ('Port'),
            editable => 1,
           ),
        new EBox::Types::Boolean(
            fieldName => 'keep',
            printableName => (q{Don't delete retrieved mail from external server}),
            defaultValue => 0,
            editable => 1,
           ),
        new EBox::Types::Boolean(
            fieldName => 'fetchall',
            printableName => (q{Fetch already read messages}),
            defaultValue => 0,
            editable => 1,
           ),
    );
    my $dataTable =
    {
        tableName          => 'ExternalAccounts',
        printableTableName => __('External mail accounts'),
        printableRowName    => __('external mail account'),
        defaultActions     => ['add', 'editField', 'del', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        help               => __('Fetching mail is done every 10 minutes'),
        modelDomain        => 'Mail',

    };

    return $dataTable;
}

sub userCorner
{
    return 1;
}

sub _mailProtocols
{
    return [
        {
            value => 'pop3',
            printableValue => 'POP3',
        },
        {
            value => 'pop3s',
            printableValue => __('Secure POP3'),
        },
        {
            value => 'imap',
            printableValue => 'IMAP',
        },
        {
            value => 'imaps',
            printableValue => __('Secure IMAP'),
        }

       ];
}

sub _user
{
    my ($self) = @_;

    my $usercornerMod = EBox::Global->modInstance('usercorner');
    my ($user, $pass, $userDN) = $usercornerMod->userCredentials();
    my $zentyalUser = new EBox::Samba::User(samAccountName => $user);
    unless ($zentyalUser->exists()) {
        throw EBox::Exceptions::External(
            __x('User {x} not found in LDAP database'), x => $user);
    }
    return $zentyalUser;
}

sub _userExternalAccounts
{
    my ($self) = @_;
    my $user = $self->_user();

    my $accounts = $self->{mailMod}->{fetchmail}->externalAccountsForUser($user);
    return $accounts;
}

sub _userAccount
{
    my ($self) = @_;
    my $user = $self->_user();
    return $self->{mailMod}->{musers}->userAccount($user);
}

sub ids
{
    my ($self) = @_;
    my $accounts = $self->_userExternalAccounts();
    my $nAccounts = scalar @{ $accounts };
    if ($nAccounts == 0) {
        return [];
    }

    my @ids = (1 .. ($nAccounts));
    return \@ids;
}

# Method: row
#
#       Return the row reading data from LDAP.
#
# Overrides:
#
#       <EBox::Model::DataTable::row>
#
sub row
{
    my ($self, $id) = @_;

    my $userAccounts = $self->_userExternalAccounts();
    if (not exists $userAccounts->[$id - 1]) {
        return undef;
    }

    my $account =  $userAccounts->[$id - 1];
    my %values = %{ $self->{mailMod}->{fetchmail}->externalAccountRowValues($account) };
    my $row = $self->_setValueRow(%values);
    $row->setId($id);
    return $row;
}

sub validateTypedRow
{
    my ($self, $action, $params_r, $all_r) = @_;

    if (exists $params_r->{externalAccount}) {
        my $externalAccount =  $params_r->{externalAccount}->value();
        $self->{mailMod}->{fetchmail}->checkExternalAccount($externalAccount);
    }

    if (exists $params_r->{password}) {
        my $password = $params_r->{password}->value();
        $self->{mailMod}->{fetchmail}->checkPassword($password);
    }
}

# Method: addTypedRow
#
# Overrides:
#
#       <EBox::Model::DataTable::addTypedRow>
#
sub addTypedRow
{
    my ($self, $params_r, %optParams) = @_;

    # Check compulsory fields
    $self->_checkCompulsoryFields($params_r);

    # check externalAccount is unique
    $self->_checkFieldIsUnique($params_r->{externalAccount});

    # validate row to add
    $self->validateTypedRow('add', $params_r, $params_r);

    my $addParams = $self->_elementsToParamsForFetchmailLdapCall($params_r);
    push @{ $addParams}, user => $self->_user();

    $self->{mailMod}->{fetchmail}->addExternalAccount(@{ $addParams });

    $self->setMessage(__('External account added'));

    # this is the last row account added and id == pos
    my $accounts = $self->_userExternalAccounts();
    my $nAccounts = scalar @{ $accounts };
    return $nAccounts;
}

sub removeRow
{
    my ($self, $id, $force) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument(
                "Missing row identifier to remove");
    }

    my $row = $self->row($id);
    if (not defined $row) {
        throw EBox::Exceptions::Internal(
           "Row with id $id does not exist, so it cannot be removed"
          );
    }

    my $user            = $self->_user();
    my $externalAccount = $row->valueByName('externalAccount');
    $self->{mailMod}->{fetchmail}->removeExternalAccount($user, $externalAccount);

    $self->setMessage(__x('External account {ac} removed',
                          ac => $externalAccount)
                     );
}

sub setTypedRow
{
    my ($self, $id, $paramsRef, %optParams) = @_;

    my $force = delete $optParams{'force'};
    my $readOnly = delete $optParams{'readOnly'};

    my $oldRow = $self->row($id);
    my $allHashElements = $oldRow->hashElements();
    my $oldAccount = $oldRow->printableValueByName('externalAccount');

    # check externalAccount is unique
    if (exists $paramsRef->{externalAccount}) {
        $self->_checkFieldIsUnique($paramsRef->{externalAccount});
    }

    $self->validateTypedRow('update', $paramsRef, $allHashElements);

    # replace old values with setted ones
    while (my ($name, $value) = each %{ $paramsRef } ) {
        $allHashElements->{$name} = $value;
    }

    my $newAccount =
          $self->_elementsToParamsForFetchmailLdapCall($allHashElements);
    $self->{mailMod}->{fetchmail}->modifyExternalAccount(
                                                 $self->_user,
                                                 $oldAccount,
                                                 $newAccount
                                                        );

}

sub _elementsToParamsForFetchmailLdapCall
{
    my ($self, $params_r) = @_;

    my @callParams = (
        externalAccount =>  $params_r->{externalAccount}->value(),,
        localAccount   => $self->_userAccount(),
        password       => $params_r->{password}->value(),
        mailServer     => $params_r->{server}->value(),
        port           => $params_r->{port}->value(),
        keep           => $params_r->{keep}->value(),
        fetchall       => $params_r->{fetchall}->value(),
       );

    my $mailProtocol = $params_r->{protocol}->value();
    if ($mailProtocol eq 'pop3') {
        push @callParams, (
            mailProtocol => 'pop3',
            ssl          => 0,
           );
    } elsif ($mailProtocol eq 'pop3s') {
        push @callParams, (
            mailProtocol => 'pop3',
            ssl          => 1,
           );
    } elsif ($mailProtocol eq 'imap') {
        push @callParams, (
            mailProtocol => 'imap',
            ssl          => 0,
           );
    } elsif ($mailProtocol eq 'imaps') {
        push @callParams, (
            mailProtocol => 'imap',
            ssl          => 1,
           );
    } else {
        throw EBox::Exceptions::Internal(
            "Unknown mail protocol: $mailProtocol"
           );
    }

    return \@callParams;
}

# Method: _checkRowExist
#
#   Override <EBox::Model::DataTable::_checkRowExist> as DataTable try to check
#   if a row exists checking the existance of the conf directory
sub _checkRowExist
{
    my ($self, $id) = @_;
    return 1;
}

1;
