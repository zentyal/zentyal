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

package EBox::Mail::CGI::CreateAccount;

use base 'EBox::CGI::ClientRawBase';

use EBox::Global;
use EBox::Mail;
use EBox::Gettext;
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
    $self->{json} = { success => 0};

    my $mail = EBox::Global->modInstance('mail');

    $self->_requireParam('user', __('user'));
    my $userDN = $self->unsafeParam('user');
    $self->{json}->{userDN} = $userDN;

    my $user = new EBox::Samba::User(dn => $userDN);
    $self->_requireParam('vdomain', __('virtual domain'));
    my $vdomain = $self->param('vdomain');
    $self->_requireParam('lhs', __('Mail address'));
    my $lhs = $self->param('lhs');
    my $mdsize = 0;
    if (defined($self->param('mdsize'))) {
        $mdsize = $self->param('mdsize');
    }

    $mail->{musers}->setUserAccount($user, $lhs, $vdomain, $mdsize);

    my $newAccount = $lhs . '@' .$vdomain;
    $self->{json}->{msg} = __x('{acc} account created', acc => $newAccount);
    $self->{json}->{mail} = $newAccount;
    $self->{json}->{success} = 1;
}

1;
