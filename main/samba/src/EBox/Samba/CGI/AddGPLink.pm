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

use EBox::Global;
use EBox::Gettext;
use EBox::Samba::GPO;
use Encode;

use constant LINK_ENABLED   => 0x00000000;
use constant LINK_DISABLED  => 0x00000001;
use constant LINK_ENFORCED  => 0x00000002;

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

    my $sambaMod = EBox::Global->modInstance('samba');
    my $gpos = $sambaMod->gpos();

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

        $self->_addLink($containerDN, $gpoDN, $linkEnabled, $enforced);

        $self->{json}->{success} = 1;
        $self->{json}->{redirect} = '/Samba/Tree/GPOLinks';
    }
}

sub _addLink
{
    my ($self, $containerDN, $gpoDN, $linkEnabled, $enforced) = @_;

    # Instantiate GPO to check DN is well-built
    my $gpo = new EBox::Samba::GPO(dn => $gpoDN);
    unless ($gpo->exists()) {
        throw EBox::Exceptions::Internal("GPO $gpoDN not found");
    }

    # Build link options
    my $linkOptions = $linkEnabled ? LINK_ENABLED : LINK_DISABLED;
    if ($enforced) {
        $linkOptions |= LINK_ENFORCED;
    }

    my $sambaMod = EBox::Global->modInstance('samba');
    my $ldb = $sambaMod->ldb();

    # Get the container entry and the current GPLink attribute
    my $result = $ldb->search({
        base => $containerDN,
        scope => 'base',
        filter => '(objectClass=*)',
        attrs => ['gpLink', 'gpOptions']});
    unless ($result->count() == 1) {
        throw EBox::Exceptions::Internal(
            "Unexpected number of entries returned");
    }
    my $containerEntry = $result->entry(0);
    my $containerGPLink = $containerEntry->get_value('gpLink');
    $containerGPLink = decode('UTF-8', $containerGPLink);

    # Add the link
    $containerGPLink .= "[LDAP://$gpoDN;$linkOptions]";
    $containerGPLink = encode('UTF-8', $containerGPLink);

    # Write GPLink attribute
    $ldb->modify($containerDN, { replace => { gpLink => $containerGPLink } });
}

1;
