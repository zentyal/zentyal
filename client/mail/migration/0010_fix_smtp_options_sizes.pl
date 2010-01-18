#!/usr/bin/perl
#
# T ofix probelm with subtypes' names of message max size and mailbox quota
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;



use Error qw(:try);



sub runGConf
{
    my ($self) = @_;
    $self->_fixMaxSize();
    $self->_fixMailboxQuota();
}



sub _fixMailboxQuota
{
    my ($self) = @_;
    $self->_fix('mailboxQuota_selected', 'mailboxUnlimited', 'mailboxSize');

}


sub _fixMaxSize
{
    my ($self) = @_;
    $self->_fix('maxSize_selected', 'unlimitedMsgSize', 'msgSize');

}

sub _fix
{
    my ($self, $selectedType,  $unlimitedGoodType, $sizeGoodType)= @_;

    my $mail = $self->{gconfmodule};
    my $dir       = 'SMTPOptions';    
    

    my $selectedTypeKey = "$dir/$selectedType";
    my $selectedValue = $mail->get_string($selectedTypeKey);
    if (not $selectedValue) {
        # uninitialized field, nothing to do
        return;
    } elsif (($selectedValue eq $unlimitedGoodType) or 
             ( $selectedValue eq $sizeGoodType)) {
        # good values, nothing to do
        return;
    }

    if ($selectedValue =~ m/unlimited/i) {
        # bad unlimited value
        $mail->set_string($selectedTypeKey, $unlimitedGoodType);
        return;
    }

    # fetch size value 
    my $goodSizeKey = "$dir/$sizeGoodType";
    my $badSizeKey = "$dir/$selectedValue";
    my $sizeValue = $mail->get_int($badSizeKey);
    # fix values
    $mail->set_string($selectedTypeKey, $sizeGoodType);
    $mail->set_int($goodSizeKey, $sizeValue);
    $mail->unset($badSizeKey)
}

EBox::init();

my $mailMod = EBox::Global->modInstance('mail');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mailMod,
        'version' => 10
        );
$migration->execute();
