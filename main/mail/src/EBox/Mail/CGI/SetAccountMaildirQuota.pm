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
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use warnings;

package EBox::Mail::CGI::SetAccountMaildirQuota;
use base 'EBox::CGI::ClientRawBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::Samba::User;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Mail', @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;
    $self->{json}->{success} = 0;

    $self->_requireParam('user', __('user'));
    my $userDN = $self->unsafeParam('user');
    $self->{json}->{userDN} = $userDN;

    $self->_requireParam('quotaType');
    my $quotaType = $self->param('quotaType');

    my $user = new EBox::Samba::User(dn => $userDN);
    my $mail = EBox::Global->modInstance('mail');
    if ($quotaType eq 'noQuota') {
        $mail->{musers}->setMaildirQuotaUsesDefault($user, 0);
        $mail->{musers}->setMaildirQuota($user, 0);
    } elsif ($quotaType eq 'default') {
        $mail->{musers}->setMaildirQuotaUsesDefault($user, 1);
    } else {
        $self->_requireParam('maildirQuota');
        my $quota = $self->param('maildirQuota');
        if ($quota <= 0) {
            throw EBox::Exceptions::External(
__('Quota must be a amount of MB greter than zero')
               );
        }
        $mail->{musers}->setMaildirQuota($user, $quota);
        $mail->{musers}->setMaildirQuotaUsesDefault($user, 0);
    }

    $self->{json}->{msg} = __('Mail directory quota set');
    $self->{json}->{success} = 1;
}

1;
