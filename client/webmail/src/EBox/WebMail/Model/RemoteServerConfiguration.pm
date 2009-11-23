# Copyright (C) 2009 eBox Technologies
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



package EBox::WebMail::Model::RemoteServerConfiguration;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::Password;
use EBox::Types::Select;
use EBox::Types::Host;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Types::Port;
use EBox::Types::Composite;

# eBox exceptions used
use EBox::Exceptions::External;

sub new
{
    my $class = shift @_ ;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}



sub _table
{
    my @tableDesc =
        (
         new EBox::Types::Host(
                               fieldName => 'imapServer',
                               printableName => __('IMAP Server'),
                               editable => 1,
                               defaultValue => '127.0.0.1',
                              ),
         new EBox::Types::Select(
                               fieldName => 'imapConnection',
                               printableName => __('IMAP connection type'),
                               editable => 1,
                               populate => \&_connectionTypePopulate,
                               defaultValue => 'unencrypted',
                              ),
         new EBox::Types::Port(
                               fieldName => 'imapPort',
                               printableName => __('IMAP server port'),
                               editable => 1,
                               defaultValue => 143,
                              ),
         new EBox::Types::Host(
                               fieldName => 'smtpServer',
                               printableName => __('SMTP Server'),
                               editable => 1,
                               defaultValue => '127.0.0.1',
                              ),
         new EBox::Types::Select(
                               fieldName => 'smtpConnection',
                               printableName => __('SMTP connection type'),
                               editable => 1,
                               populate => \&_connectionTypePopulate,
                               defaultValue => 'unencrypted',
                              ),
         new EBox::Types::Port(
                               fieldName => 'smtpPort',
                               printableName => __('SMTP server port'),
                               editable => 1,
                               defaultValue => 25,
                              ),
         new EBox::Types::Union(
                              fieldName => 'smtpAuth',
                              printableName =>
                                __('SMTP authentication'),
                              editable => 1,
# XXX Workaround to allow unsafe characters in Password.
#     Union + Composite make difficult to call password method
                              allowUnsafeChars => 1,
                              subtypes => [
                              new EBox::Types::Union::Text(
                                  'fieldName' => 'none',
                                  'printableName' => __('None'),
                                  ),
                              new EBox::Types::Union::Text(
                                  'fieldName' => 'same',
                                  'printableName' => __('Same user and password than IMAP'),
                                  ),
                              new EBox::Types::Composite(
                                   fieldName => 'userandpassword',
                                   printableName => __('User and password'),
                                   editable => 1,
                                   showTypeName => 0,
                                   types => [
                                             new EBox::Types::Text(
                                              fieldName => 'username',
                                              printableName => __('User'),
                                              size => 20,
                                              editable => 1,
                                                                  ),
                                             new EBox::Types::Password(
                                              fieldName => 'password',
                                              printableName => __('Password'),
                                              size => 12,
                                              editable => 1,
                                              allowUnsafeChars => 1,
                                                                  ),

                                            ],
                                                        )
                                  ],
             ),
         new EBox::Types::Boolean(
                                  fieldName => 'managesieve',
                                  printableName =>
                                  __('Manage sieve enabled in IMAP server'),
                                  editable => 1,
                                 ),
         new EBox::Types::Port(
                               fieldName => 'managesievePort',
                               printableName => __('Manage sieve port'),
                               editable => 1,
                               defaultValue => 4190,
                              ),
         new EBox::Types::Boolean(
                                  fieldName => 'managesieveTls',
                                  printableName =>
                                  __('Manage sieve connection uses TLS'),
                                  editable => 1,
                                 ),
         


        );

      my $dataForm = {
                      tableName          => __PACKAGE__->nameFromClass(),
                      printableTableName => __('External server connection'),
                      modelDomain        => 'WebMail',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,

                     };



    return $dataForm;
}


sub _connectionTypePopulate
{
    return [
        { 
            value => 'unencrypted', 
            printableValue =>__('unencrypted'),
        },
        { 
            value => 'ssl', 
            printableValue =>__('SSL'),
        },
        { 
            value => 'tls', 
            printableValue =>__('TLS'),
        },

       ];
}


sub _urlForConnection
{
    my ($address, $connectionType) = @_;
    if ($connectionType eq 'ssl') {
        return 'ssl://' . $address;
    } elsif ($connectionType eq 'tls') {
        return 'tls://' . $address;
    }

    # plain connection...
    return $address;
}

sub getConfiguration
{
    my ($self) = @_;
    my $row = $self->row();

    my @params;

    my $imapServer = $row->elementByName('imapServer')->value();
    my $imapConnection = 
        $row->elementByName('imapConnection')->value();
    my $imapUrl = _urlForConnection($imapServer, $imapConnection);
    
    my $imapPort = $row->elementByName('imapPort')->value();
    push @params, (
                   imapServer => $imapUrl,
                   imapPort   => $imapPort,                   
                  );

    my $smtpServer = $row->elementByName('smtpServer')->value();
    my $smtpConnection = 
        $row->elementByName('smtpConnection')->value();
    my $smtpUrl = _urlForConnection($smtpServer, $smtpConnection);

    my $smtpPort = $row->elementByName('smtpPort')->value();
    push @params, (
                   smtpServer => $smtpUrl,
                   smtpPort   => $smtpPort,                   
                  );


    my $smtpAuth = $row->elementByName('smtpAuth');
    if ($smtpAuth->selectedType() eq 'same') {
        push @params, (
                       smtpUser     => '%u',
                       smtpPassword => '%p',
                      );
    } elsif ($smtpAuth->selectedType() eq 'userandpassword') {
        my $credentials = $smtpAuth->value();
        push @params, (
                       smtpUser => $credentials->{username},
                       smtpPassword => $credentials->{password},
                      );
    }
    

    return \@params;
}


sub getSieveConfiguration
{
    my ($self) = @_;
    my $row = $self->row();

    my @params;

    my $imapServer = $row->elementByName('imapServer')->value();
    my $port       = $row->elementByName('managesievePort')->value();
    my $tls        = $row->elementByName('managesieveTls')->value();
    @params = (
               host => $imapServer,
               port => $port,
               tls  => $tls,
              );

    return \@params;
}

sub validateTypedRow
{
    my ($self, $action, $changedFields) = @_;
    if (exists $changedFields->{smarthost}) {
        $self->_validateSmarthost($changedFields);
    }

}


sub precondition
{
    my $webmail = EBox::Global->modInstance('webmail');
    my $mode = $webmail->model('OperationMode');
    return (not $mode->usesEBoxMail())
}


sub preconditionFailMsg
{
    return __(
q{No need to configure the connection to a remote server beacuse WebMail is configured to use eBox's mail service'} 
);
}


1;

