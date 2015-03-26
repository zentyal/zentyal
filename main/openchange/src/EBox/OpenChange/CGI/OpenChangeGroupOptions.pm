# Copyright (C) 2015 Zentyal S.L.
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

package EBox::OpenChange::CGI::OpenChangeGroupOptions;
use base 'EBox::CGI::ClientPopupBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Samba::User;
use EBox::OpenChange::LdapUser;

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new('title' => 'OpenChange',
                                  @_);

    bless ($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    $self->{json}->{success} = 0;
    my $ldap = new EBox::OpenChange::LdapUser();

    $self->_requireParam('group', __('group'));
    my $groupDN = $self->unsafeParam('group');
    $self->{json}->{groupDN} = $groupDN;

    my $ldapGroup = new EBox::Samba::Group(dn => $groupDN);
    unless (defined $ldapGroup and $ldapGroup->exists()) {
        throw EBox::Exceptions::Internal("Cannot instance group $groupDN");
    }

    if ($self->param('active') eq 'yes') {
        $ldap->setGroupAccountEnabled($ldapGroup, 1);
        $self->{json}->{enabled} = 1;
        $self->{json}->{msg} = __('OpenChange account enabled');
    } else {
        $ldap->setGroupAccountEnabled($ldapGroup, 0);
        $self->{json}->{enabled} = 0;
        $self->{json}->{msg} = __('OpenChange account disabled');
    }

    $self->{json}->{success} = 1;
}

1;
