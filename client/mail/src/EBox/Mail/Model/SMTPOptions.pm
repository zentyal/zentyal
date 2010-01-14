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



package EBox::Mail::Model::SMTPOptions;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Password;
use EBox::Types::Boolean;
use EBox::Types::Host;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Types::Port;
use EBox::Types::Composite;
use EBox::Types::MailAddress;

# eBox exceptions used
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
         new EBox::Types::MailAddress(
             fieldName => 'bounceReturnAddress',
             printableName => __('Return address for mail bounced back to the sender'),
             defaultValue => 'noreply@example.com',
             editable => 1,
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
                                  'printableName' => __('size in Mb'),
                                  'editable'  => 1,
                                  'min'       => 1,
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
                                  'printableName' => __('size in Mb'),
                                  'editable'  => 1,
                                  'min'       => 1,
                                  'max'       => MAX_MSG_SIZE,
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
                                  'printableName' => __('days'),
                                  'editable'  => 1,
                                  'min'       => 1,
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
                                  'printableName' => __('days'),
                                  'editable'  => 1,
                                  'min'       => 1,
                                      ),
                                  ],
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
    if ($maxSize->selectedType eq 'unlimited') {
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

}


sub _validateSmarthost
{
    my ($self, $changedFields) = @_;

    my $smarthost = $changedFields->{smarthost}->value();
    if (not $smarthost) {
        # no smarthost, correct..
        return undef;
    }


    if ($smarthost =~ m/:/) {
        my ($host, $port) = split ':', $smarthost;
        EBox::Validate::checkHost($host, __(q{Smarthost's address}));
        EBox::Validate::checkPort($port, __(q{Smarthost's port}));
        
    }else {
        EBox::Validate::checkHost($smarthost, __(q{Smarthost's address}));
        
    }


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



1;

