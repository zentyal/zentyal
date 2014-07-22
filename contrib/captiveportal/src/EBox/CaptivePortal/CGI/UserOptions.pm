# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::CaptivePortal::CGI::UserOptions;
use base 'EBox::CGI::ClientPopupBase';

use EBox::Global;
use EBox::Gettext;
use EBox::CaptivePortal::LdapUser;
use EBox::Users::User;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Captive Portal',
                                      @_);

    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;
    $self->{json}->{success} = 0;
    my $cpldap = new EBox::CaptivePortal::LdapUser;

    $self->_requireParam('user', __('user'));
    my $userDN = $self->unsafeParam('user');
    $self->{json}->{userDN} = $userDN;

    my $user = new EBox::Users::User(dn => $userDN);

    my $overridden = not ($self->param('CaptiveUser_defaultQuota_selected') eq
                     'defaultQuota_default');

    my $quota = 0;
    if ($self->param('CaptiveUser_defaultQuota_selected') eq
        'defaultQuota_size') {
        $quota = $self->param('CaptiveUser_defaultQuota_size');
    }
    $cpldap->setQuota($user, $overridden, $quota);

    $self->{json}->{msg} = __('User quota set');
    $self->{json}->{success} = 1;
}

1;
