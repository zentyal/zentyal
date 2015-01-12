# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::Samba::CGI::ActiveSharing;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::LdapUserImplementation;
use EBox::Samba;
use EBox::Gettext;
use EBox::Exceptions::External;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Users and Groups', @_);
    bless ($self, $class);
    return $self;
}

sub _group
{
    my ($self) = @_;

    my $smbldap = new EBox::LdapUserImplementation;

    $self->_requireParam('group', __('group'));
    my $groupDN = $self->unsafeParam('group');
    my $group = new EBox::Samba::Group(dn => $groupDN);

    $self->_requireParamAllowEmpty('sharename', __('share name'));
    my $name =  $self->param('sharename');

    my $namechange = $self->param('namechange');
    if ($namechange or $self->param('add')) {
        $smbldap->setGroupShare($group, $name);
        if ($namechange) {
            $self->{json}->{msg} = __('Group share renamed');
        } else {
            $self->{json}->{msg} = __('Group share added');
        }
        $self->{json}->{share} = 1;
    } elsif ($self->param('remove')) {
        $smbldap->removeGroupShare($group->name());
        $self->{json}->{msg} = __('Group share removed');
        $self->{json}->{share} = 0;
    } else {
        $self->{json}->{msg} = __('Group share set');
        $self->{json}->{share} = 1;
    }

    $self->{json}->{success} = 1;
}

sub _process
{
    my ($self) = @_;
    $self->{json}->{success} = 0;

    $self->_group();
}

1;
