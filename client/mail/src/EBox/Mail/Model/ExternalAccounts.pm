# Copyright (C) 2009 eBox Technologies S.L.
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


package EBox::Mail::Model::ExternalAccounts;
use base 'EBox::Model::DataTable';

#
#      Yo manage retrieval of email form external ccounts in the user cornes
#



use strict;
use warnings;

use EBox::Gettext;
use EBox::Types::Password;
use EBox::Types::MailAddress;
use EBox::Types::Host;
use EBox::Types::Select;
use EBox::Types::Port;
use EBox::Global;
use Apache2::RequestUtil;



sub new
{
   my $class = shift;

   my $self = $class->SUPER::new(@_);
   $self->{mailMod} = EBox::Global->modInstance('mail');

   bless($self, $class);

   return $self;
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
        new EBox::Types::MailAddress(
            fieldName     => 'externalAccount',
            printableName => __('External mail address'),
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
  
    );
    my $dataTable =
    {
        tableName          => 'ExternalAccounts',
        printableTableName => __('External mail accounts'),
        printableRowName    => __('external mail account'),
#                         'defaultController' =>
#             '/ebox/Mail/Controller/ExternalAccounts',
        defaultActions     => ['add', 'del', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        help               => 'Add and remove external account for mail retrieval',
        modelDomain        => 'mail',

    };

    return $dataTable;
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
    my $request = Apache2::RequestUtil->request();
    my $user = $request->user();
    return $user;
}

sub _userExternalAccounts
{
    my ($self) = @_;
    my $user = $self->_user();

    my $accounts = 
      $self->{mailMod}->{fetchmail}->externalAccountsForUser($user);
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

    my @ids = (0 .. ($nAccounts-1));
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
    if (not exists $userAccounts->[$id]) {
        return undef;
    }

    my $account =  $userAccounts->[$id];

    # direct correspondende values
    my %values      =  (
        externalAccount => $account->{user},
        password => $account->{password},
        server => $account->{server},
        port => $account->{port},
       );

    my $mailProtocol = $account->{mailProtocol};
    my $ssl = 0;
    if (exists $account->{options}) {
        if (ref $account->{options}) {
            $ssl = grep { $_ eq 'ssl' } @{ $account->{options} };
        } else {
            $ssl = $account->{options} eq 'ssl';
        }

    }

    my $rowProtocol;
    if ($mailProtocol eq 'pop3') {
        $rowProtocol = $ssl ? 'pop3s' : 'pop3';
    } elsif ($mailProtocol eq 'imap') {
        $rowProtocol = $ssl ? 'imaps' : 'imap';
    }else {
        throw EBox::Exceptions::Internal(
         "Unknown mail protocol: $mailProtocol"
           );
    }
    $values{protocol} = $rowProtocol;

    my $row = $self->_setValueRow(%values);
    $row->setId($id);

    return $row;
}



# Method: _addTypedRow
#
# Overrides:
#
#       <EBox::Model::DataTable::_addTypedRow>
#
sub addTypedRow
{
    my ($self, $params_r, %optParams) = @_;

    # Check compulsory fields
    $self->_checkCompulsoryFields($params_r);

    # check externalAccount is unique
    $self->_checkFieldIsUnique($params_r->{externalAccount});


    my $addParams = $self->_elementsToParamsForFetchmailLdapCall($params_r);
    push @{ $addParams}, user => $self->_user();

    $self->{mailMod}->{fetchmail}->addExternalAccount(@{ $addParams });


    $self->setMessage(__('External account added'));
}


sub removeRow
{
    my ($self, $id, $force) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument(
                "Missing row identifier to remove")
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

    # check externalAccount is unique
    if (exists $paramsRef->{externalAccount}) {
        $self->_checkFieldIsUnique($paramsRef->{externalAccount});
    }

    # replace old values with setted ones
    while (my ($name, $value) = each %{ $paramsRef } ) {
        $allHashElements->{$name} = $value;
    }



    my $newAccount = $self->_elementsToParamsForFetchmailLdapCall($paramsRef);
    $self->{mailMod}->{fetchmail}->modifyExternalAccount(
                                                 $self->_user,
                                                 $paramsRef->{externalAccount},
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



sub precondition
{
    my ($self) = @_;
    my $account = $self->_userAccount();
    return defined $account;
}


sub preconditionFailMsg
{
    return
__('Cannot retrieve mail from external ccounts because do you dont have a email account in a local mail domain')
        ;
}

1;
