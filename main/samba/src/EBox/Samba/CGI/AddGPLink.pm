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

package EBox::Samba::CGI::AddGPLink;

use base 'EBox::CGI::ClientPopupBase';

use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Samba::GPO;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/samba/addgplink.mas', @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    $self->_requireParam('dn', 'Container DN');
    my $containerDN = $self->unsafeParam('dn');

    my $usersMod = EBox::Global->modInstance('samba');
    my $gpos = $usersMod->gpos();

    my $params = [];
    push (@{$params}, dn => $containerDN);
    push (@{$params}, gpos => $gpos);
    $self->{params} = $params;

    if ($self->param('add')) {
        $self->{json} = { success => 0 };
        $self->_requireParam('gpoDN', __('GPO DN'));
        my $gpoDN = $self->param('gpoDN');
        my $linkEnabled = $self->param('linkEnabled') ? 1 : 0;
        my $enforced = $self->param('enforced') ? 1 : 0;

        my $gpo = new EBox::Samba::GPO(dn => $gpoDN);
        unless ($gpo->exists()) {
            throw EBox::Exceptions::Internal("GPO $gpoDN does not exists");
        }
        $gpo->link($containerDN, $linkEnabled, $enforced);

        $self->{json}->{success} = 1;
        $self->{json}->{redirect} = '/Samba/Tree/GPOLinks';
    }
}

1;
