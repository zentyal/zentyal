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

package EBox::Mail::CGI::DelAccount;

use base 'EBox::CGI::ClientRawBase';

use EBox::Global;
use EBox::Mail;
use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::Samba::User;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Mail',
                                  @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;
    $self->{json}->{success} = 0;
    my $global = EBox::Global->getInstance();
    my $mail = $global->modInstance('mail');

    $self->_requireParam('user', __('user'));
    my $userDN = $self->unsafeParam('user');
    $self->{json}->{userDN}  = $userDN;

    $self->_requireParam('mail', __('user mail'));
    my $usermail = $self->param('mail');
    $self->{json}->{mail} = $usermail;

    my $user = new EBox::Samba::User(dn => $userDN);
    $mail->{musers}->delUserAccount($user);

    $self->{json}->{msg} = __x('{acc} account removed', acc => $usermail);
    $self->{json}->{mail} = '';
    $self->{json}->{ocEnabled} = 0;
    $self->{json}->{success} = 1;
}

1;
