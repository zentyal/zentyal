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

package EBox::Samba::CGI::DeleteGPLink;

use base 'EBox::CGI::ClientPopupBase';

use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Samba::GPO;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/samba/delgplink.mas', @_);
    bless ($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    $self->_requireParam('containerDN', __('Container DN'));
    $self->_requireParam('linkIndex', __('GPO Link index'));
    $self->_requireParam('gpoDN', __('GPO DN'));

    my $containerDN = $self->unsafeParam('containerDN');
    my $linkIndex = $self->unsafeParam('linkIndex');
    my $gpoDN = $self->unsafeParam('gpoDN');

    my $params = [];
    push (@{$params}, containerDN => $containerDN);
    push (@{$params}, linkIndex => $linkIndex);
    push (@{$params}, gpoDN => $gpoDN);
    $self->{params} = $params;

    if ($self->param('del')) {
        $self->{json} = { success => 0 };
        my $gpo = new EBox::Samba::GPO(dn => $gpoDN);
        unless ($gpo->exists()) {
            throw EBox::Exceptions::Internal("GPO $gpoDN does not exists");
        }
        $gpo->unlink($containerDN, $linkIndex);
        $self->{json}->{success} = 1;
        $self->{json}->{redirect} = '/Samba/Tree/GPOLinks';
    }
}

1;
