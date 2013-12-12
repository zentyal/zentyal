# Copyright (C) 2012-2012 Zentyal S.L.
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

package EBox::CGI::Mail::DelExternalAccount;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::UsersAndGroups::User;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my $self = shift;
    my $mail = EBox::Global->modInstance('mail');

    $self->_requireParam('user', __('user'));
    my $userDN = $self->unsafeParam('user');
    $self->{redirect} = "UsersAndGroups/User?user=".$userDN;
    $self->keepParam('user');

    $self->_requireParam('account', __('External mail account'));
    my $account = $self->unsafeParam('account');

    my $user = new EBox::UsersAndGroups::User(dn => $userDN);
    $mail->{fetchmail}->removeExternalAccount($user, $account);
}

1;
