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

package EBox::Samba::CGI::EditGPLink;

use base 'EBox::CGI::ClientPopupBase';

use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Samba::GPO;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/samba/editgplink.mas', @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    $self->_requireParam('containerDN', 'Container DN');
    $self->_requireParam('gpoDN', 'GPO DN');
    $self->_requireParam('linkIndex', 'Link Index');
    #$self->_requireParamAllowEmpty('linkEnabled', 'Link Enabled');
    #$self->_requireParamAllowEmpty('enforced', 'Link Enforced');

    my $containerDN     = $self->unsafeParam('containerDN');
    my $gpoDN           = $self->unsafeParam('gpoDN');
    my $gpoDisplayName  = $self->unsafeParam('gpoDisplayName');
    my $linkIndex       = $self->unsafeParam('linkIndex');
    my $linkEnabled     = $self->unsafeParam('linkEnabled');
    my $enforced        = $self->unsafeParam('enforced');

    my $params = [];
    push (@{$params}, containerDN => $containerDN);
    push (@{$params}, gpoDN => $gpoDN);
    push (@{$params}, gpoDisplayName => $gpoDisplayName);
    push (@{$params}, linkIndex => $linkIndex);
    push (@{$params}, linkEnabled => $linkEnabled);
    push (@{$params}, enforced => $enforced);
    $self->{params} = $params;

    if ($self->param('edit')) {
        $self->{json} = { success => 0 };

        $enforced = $self->param('enforced') ? 1 : 0;
        $linkEnabled = $self->param('linkEnabled') ? 1 : 0;

        my $gpo = new EBox::Samba::GPO(dn => $gpoDN);
        unless ($gpo->exists()) {
            throw EBox::Exceptions::Internal("GPO $gpoDN does not exists");
        }
        $gpo->editLink($containerDN, $linkIndex, $linkEnabled, $enforced);

        $self->{json}->{success} = 1;
        $self->{json}->{redirect} = '/Samba/Tree/GPOLinks';
    }
}

1;
