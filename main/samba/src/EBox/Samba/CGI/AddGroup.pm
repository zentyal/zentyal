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

package EBox::Samba::CGI::AddGroup;

use base 'EBox::CGI::ClientPopupBase';

use EBox::Global;
use EBox::Samba;
use EBox::Samba::Group;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/samba/addgroup.mas', @_);
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
        $self->_requireParam('groupname', __('group name'));
        $self->_requireParam('type', __('group type'));
        $users->checkMailNotInUse($self->unsafeParam('mail'));

        my $groupname = $self->param('groupname');

        my $group = EBox::Samba::Group->create(
            name            => $groupname,
            parent          => $users->objectFromDN($dn),
            description     => $self->unsafeParam('description'),
            mail            => $self->unsafeParam('mail'),
            isSecurityGroup => ($self->param('type') eq 'security'),
        );

        $self->{json}->{success} = 1;
        $self->{json}->{redirect} = '/Samba/Tree/Manage';
    }
}

1;
