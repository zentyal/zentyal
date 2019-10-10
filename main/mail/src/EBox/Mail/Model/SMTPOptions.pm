# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Mail::Model::SMTPOptions;

use base 'EBox::Model::DataForm';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Password;
use EBox::Types::Boolean;
use EBox::Types::Select;
use EBox::Types::Host;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Types::Port;
use EBox::Types::Composite;
use EBox::Types::MailAddress;
use TryCatch;
use HTML::Entities;

use EBox::Exceptions::External;

use constant MAX_MSG_SIZE                          => '100';

sub new
{
    my $class = shift @_ ;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method:  _table
#
# This method overrides <EBox::Model::DataTable::_table> to return
# a table model description.
#
# This table is composed of two fields:
#
#   domain (<EBox::Types::Text>)
#   enabled (EBox::Types::Boolean>)
#
# The only avaiable action is edit and only makes sense for 'enabled'.
#
sub _table
{
    my @tableDesc =
        (
         new EBox::Types::Text(
                               fieldName => 'smarthost',
                               printableName => __('Smarthost to send mail'),
                               optional => 1,
                               editable => 1,
                               help     => __('The format is host[:port] being '
                                              . 'port set to 25 if none is supplied'),
                               allowUnsafeChars => 1,
                              ),
         new EBox::Types::Union(
                              fieldName => 'smarthostAuth',
                              printableName =>
                                __('Smarthost authentication'),
                              editable => 1,
# XXX Workaround to allow unsafe characters in Password.
#     Union + Composite make difficult to call password method
                              allowUnsafeChars => 1,
                              subtypes => [
                              new EBox::Types::Union::Text(
                                  'fieldName' => 'none',
                                  'printableName' => __('None'),
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
                                             new EBox::Types::Select(
                                              fieldName => 'auth',
                                              printableName => __('Authentication'),
                                              editable => 1,
                                              populate => \&_populateAuth,
                                                                  ),

                                            ],
                                                        )
                                  ],
             ),
         new EBox::Types::Union(
                              fieldName => 'mailname',
                              printableName =>
                                __('Server mailname'),
                              subtypes => [
                              new EBox::Types::Union::Text(
                                  'fieldName' => 'fqdn',
                                  'printableName' => __('FQDN hostname'),
                                  ),
                              new EBox::Types::Text(
                                  'fieldName' => 'custom',
                                  'printableName' => __('custom'),
                                  'editable'  => 1,
                                      ),
                                  ],
             ),
         new EBox::Types::Union(
                              fieldName => 'postmasterAddress',
                              printableName =>
                                __('Postmaster address'),
                              help =>
                      __('Address used to report mail problems'),
                              subtypes => [
                              new EBox::Types::Union::Text(
                                  'fieldName' => 'postmasterRoot',
                                  'printableName' => __('Local root account'),
                                  ),
                              new EBox::Types::MailAddress(
                                  'fieldName' => 'postmasterCustom',
                                  'printableName' => __('Custom address'),
                                  'editable'  => 1,
                                      ),
                                  ],
             ),
         new EBox::Types::Union(
                              fieldName => 'mailboxQuota',
                              printableName =>
                                __('Maximum mailbox size allowed'),
                              help =>
 __('When a mailbox reaches this size futher messages will be rejected. This can be overidden by account'),
                              subtypes => [
                              new EBox::Types::Union::Text(
                                  'fieldName' => 'mailboxUnlimited',
                                  'printableName' => __('Unlimited size'),
                                  ),
                              new EBox::Types::Int(
                                  'fieldName' => 'mailboxSize',
                                  'printableName' => __('limited to'),
                                  'trailingText'  => 'MB',
                                  'editable'  => 1,
                                  'min'       => 1,
                                  'size'      => 5,
                                      ),
                                  ],
             ),
         new EBox::Types::Union(
                              fieldName => 'maxSize',
                              printableName =>
                                __('Maximum message size accepted'),
                              subtypes => [
                              new EBox::Types::Union::Text(
                                  'fieldName' => 'unlimitedMsgSize',
                                  'printableName' => __('Unlimited size'),
                                  ),
                              new EBox::Types::Int(
                                  'fieldName' => 'msgSize',
                                  'printableName' => __('limited to'),
                                  'trailingText'  => 'MB',
                                  'editable'  => 1,
                                  'min'       => 1,
                                  'max'       => MAX_MSG_SIZE,
                                  'size'      => 5,
                                      ),
                                  ],
             ),
         new EBox::Types::Union(
                              fieldName => 'deletedExpire',
                              printableName =>
                                __('Expiration period for deleted mails'),
                              subtypes => [
                              new EBox::Types::Union::Text(
                                  'fieldName' => 'neverExpireDeleted',
                                  'printableName' => __('Never'),
                                  ),
                              new EBox::Types::Int(
                                  'fieldName' => 'daysExpireDeleted',
                                  'printableName' => __('expired in'),
                                  'trailingText'  => __('days'),
                                  'editable'  => 1,
                                  'min'       => 1,
                                  'size'      => 5,
                                      ),
                                  ],
             ),
         new EBox::Types::Union(
                              fieldName => 'spamExpire',
                              printableName =>
                                __('Expiration period for spam mails'),
                              subtypes => [
                              new EBox::Types::Union::Text(
                                  'fieldName' => 'neverExpireSpam',
                                  'printableName' => __('Never'),
                                  ),
                              new EBox::Types::Int(
                                  'fieldName' => 'daysExpireSpam',
                                  'printableName' => __('expired in'),
                                  'trailingText'  => __('days'),
                                  'editable'  => 1,
                                  'min'       => 1,
                                  'size'      => 5,
                                      ),
                                  ],
             ),
         new EBox::Types::Int(
                              fieldName => 'fetchmailPollTime',
                              printableName =>
                              __('Period for polling external mail accounts'),
                              'trailingText'  => __('minutes'),
                              'editable'  => 1,
                              'min'       => 1,
                              'size'      => 5,
                              'defaultValue' => 3,
                             ),
        );

      my $dataForm = {
                      tableName          => __PACKAGE__->nameFromClass(),
                      printableTableName => __('Options'),
                      modelDomain        => 'Mail',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,

                     };

    return $dataForm;
}

sub _populateAuth
{
    my @options;

    push (@options, { value => 'PLAIN', printableValue => 'PLAIN' });
    push (@options, { value => 'LOGIN', printableValue => 'LOGIN' });

    return \@options;
}

#
# Method: maxMsgSize
#
#  Returns:
#   - the maximum message size allowed by the server in Mb or zero if we do
#      not have any limit set
#
sub maxMsgSize
{
    my ($self) = @_;

    my $maxSize = $self->row()->elementByName('maxSize');
    if ($maxSize->selectedType eq 'unlimitedMsgSize') {
        return 0;
    }

    my $size = $maxSize->subtype()->value();
    return $size;
}

# Method: maiboxQuota
#
#   get the default maximum size for an account's mailbox.
#
#   Returns:
#      the amount in Mb or 0 for unlimited size
sub mailboxQuota
{
    my ($self) = @_;

    my $mailboxQuota = $self->row()->elementByName('mailboxQuota');
    if ($mailboxQuota->selectedType eq 'mailboxUnlimited') {
        # 0 means unlimited for dovecot's quota plugin..
        return 0;
    }

    my $size = $mailboxQuota->subtype()->value();
    return $size;
}

sub expirationForDeleted
{
    my ($self) = @_;
    return $self->_expiration('deletedExpire', 'neverExpireDeleted');
}

sub expirationForSpam
{
    my ($self) = @_;
    return $self->_expiration('spamExpire', 'neverExpireSpam');
}

sub _expiration
{
    my ($self, $element, $neverTypeName) = @_;
    my $expiration = $self->row()->elementByName($element);
    if ($expiration->selectedType eq $neverTypeName) {
        # 0 means unlimited
        return 0;
    }

    my $days = $expiration->subtype()->value();
    return $days;
}

sub validateTypedRow
{
    my ($self, $action, $changedFields) = @_;
    if (exists $changedFields->{smarthost}) {
        $self->_validateSmarthost($changedFields);
    }

    if (exists $changedFields->{mailname}) {
        $self->_validateMailname($changedFields->{mailname});
    }
}

sub _validateSmarthost
{
    my ($self, $changedFields) = @_;

    my $smarthost = HTML::Entities::encode($changedFields->{smarthost}->value());
    if (not $smarthost) {
        # no smarthost, correct..
        return undef;
    }

    my ($host, $port) = split ':', $smarthost;
    # check for not resolve MX syntax
    if ($host =~ m/^\[.*\]$/) {
        $host =~ s/^\[//;
        $host =~ s/\]$//;
    }

    EBox::Validate::checkHost($host, __(q{Smarthost's address}));
    if ($port) {
        EBox::Validate::checkPort($port, __(q{Smarthost's port}));
    }

}

sub _validateMailname
{
    my ($self, $mailname) = @_;

    my $mail = EBox::Global->modInstance('mail');

    my $value;
    if ($mailname->selectedType eq 'fqdn') {
        # no custom mailname, use fqdn
        $value = $mail->_fqdn();
    } else {
        $value =  $mailname->subtype()->value();
    }

    $mail->checkMailname($value);
}

sub customMailname
{
    my ($self) = @_;

    my $mailname = $self->row()->elementByName('mailname');
    if ($mailname->selectedType eq 'fqdn') {
        # no custom mailname, use fqdn
        return undef;
    }

    return $mailname->subtype()->value();
}

sub postmasterAddress
{
    my ($self) = @_;
    my $postmaster = $self->row()->elementByName('postmasterAddress');
    if ($postmaster->selectedType eq 'postmasterRoot') {
        return 'root';
    }

    return $postmaster->subtype()->value();
}

# Method: viewCustomizer
#
#      Return a custom view customizer to set a permanent message if
#      the mailname is incorrect
#
# Overrides:
#
#      <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);

    my $mail = EBox::Global->modInstance('mail');

    my $mailname;
    try {
        $mailname = $mail->mailname();
    } catch (EBox::Exceptions::Internal $e) {
        $mailname = undef;
    }

    my $msg;
    if (not defined $mailname) {
        $msg = __(
                q{The mailname is set to the server's hostname and the hostname is incorrect}
               );
    } elsif (not $mailname =~ m/\./) {
        my $msg;
        if ( $mailname eq $mail->_fqdn()) {
            $msg = __(
                q{The mailname is set to the server's hostname and the hostname is not } .
                    'fully qualified. '
                   );
        } else {
            $msg = __('The selected mailname is not a fully qualified hostname. ')
        }

        $msg .= __(
'Not having a fully qualified hostname could lead to some mail servers to reject ' .
'the mail and incorrect reply addresses from system users'
                    );

    }

    if ($msg) {
        $customizer->setPermanentMessage($msg);
    }

    return $customizer;
}

1;
