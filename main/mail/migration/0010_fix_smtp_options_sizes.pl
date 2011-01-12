#!/usr/bin/perl
#
# Copyright (C) 2008-2010 eBox Technologies S.L.
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

# T ofix probelm with subtypes' names of message max size and mailbox quota
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;


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
    my $dir  = 'SMTPOptions';    
    

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
    $mail->set_int($goodSizeKey, $sizeValue);
    $mail->set_string($selectedTypeKey, $sizeGoodType);
    # remove deprecated key
    $mail->unset($badSizeKey)
}

EBox::init();

my $mailMod = EBox::Global->modInstance('mail');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mailMod,
        'version' => 10
        );
$migration->execute();
