# Copyright (C) 2013 Zentyal S.L.
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

package EBox::Samba::CGI::AddContact;

use base 'EBox::CGI::ClientPopupBase';

use EBox::Global;
use EBox::Samba;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/samba/addcontact.mas', @_);
    bless ($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('samba');

    $self->_requireParam('dn', 'ou dn');
    my $dn = $self->unsafeParam('dn');

    my @params;

    push (@params, dn => $dn);

    $self->{params} = \@params;

    if ($self->param('add')) {
        $self->{json} = { success => 0 };

        $self->_requireParam('givenname', __('first name'));
        $self->_requireParam('surname', __('last name'));
        $self->_requireParamAllowEmpty('description', __('Description'));
        $self->_requireParamAllowEmpty('mail', __('E-Mail'));

        my $givenname = $self->param('givenname');
        my $surname = $self->param('surname');
        my $displayname = $self->param('displayname');

        my $contact = EBox::Samba::Contact->create(
            parent => $users->objectFromDN($dn),
            givenName => $givenname,
            sn => $surname,
            displayName => $displayname,
            description => $self->param('description'),
            mail => $self->param('mail'),
        );

        $self->{json}->{success} = 1;
        $self->{json}->{redirect} = '/Samba/Tree/Manage';
    }
}

1;
