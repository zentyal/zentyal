# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::Mail::CGI::DelExternalAccount;
use base 'EBox::CGI::ClientRawBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Samba::User;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;
    $self->{json}->{success} = 0;
    my $mail = EBox::Global->modInstance('mail');

    $self->_requireParam('user', __('user'));
    my $userDN = $self->unsafeParam('user');
    $self->{json}->{userDN} = $userDN;

    $self->_requireParam('account', __('External mail account'));
    my $account = $self->unsafeParam('account');

    my $user = new EBox::Samba::User(dn => $userDN);
    $mail->{fetchmail}->removeExternalAccount($user, $account);

    my @externalAccounts = map {
        my $account = $mail->{fetchmail}->externalAccountRowValues($_);
     } @{ $mail->{fetchmail}->externalAccountsForUser($user) };

    # XXX workaround  agains ghost value
    @externalAccounts = grep { $_->{externalAccount} ne $account  } @externalAccounts;

    $self->{json}->{externalAccounts} = \@externalAccounts;
    $self->{json}->{userDN}  = $userDN;
    $self->{json}->{msg} = __x('External account {acc} removed', acc => $account);
    $self->{json}->{success} = 1;
}

1;
