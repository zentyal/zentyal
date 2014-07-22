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

package EBox::Samba::CGI::AddOU;

use base 'EBox::CGI::ClientPopupBase';

use EBox::Global;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/samba/addou.mas', @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my $self = shift;

    $self->_requireParam('dn', 'ou dn');
    my $dn = $self->unsafeParam('dn');

    my @params;

    push (@params, dn => $dn);

    $self->{params} = \@params;

    if ($self->param('add')) {
        $self->{json} = { success => 0 };
        $self->_requireParam('ou', __('OU name'));
        my $ou = $self->param('ou');

        my $usersMod = EBox::Global->modInstance('samba');
        my $parent;
        if ($dn eq 'root') {
            $parent = $usersMod->defaultNamingContext();
        } else {
            $parent = $usersMod->objectFromDN($dn);
        }

        $usersMod->ouClass()->create(
            name   => $ou,
            parent => $parent
        );

        $self->{json}->{success} = 1;
        $self->{json}->{redirect} = '/Samba/Tree/Manage';
    }
}

1;
