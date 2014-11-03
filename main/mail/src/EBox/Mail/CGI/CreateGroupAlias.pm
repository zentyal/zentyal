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

package EBox::Mail::CGI::CreateGroupAlias;
use base 'EBox::CGI::ClientRawBase';

use EBox::Global;
use EBox::Mail;
use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::Samba::Group;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Mail',
                                  @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;
    $self->{json}->{success} = 0;

    $self->_requireParam('group', __('group'));
    my $groupDN = $self->unsafeParam('group');
    $self->{json}->{groupDN} = $groupDN;

    $self->_requireParam('lhs', __('account name'));
    $self->_requireParam('rhs', __('domain name'));

    my $lhs = $self->param('lhs');
    my $rhs = $self->param('rhs');

    my $group = new EBox::Samba::Group(dn => $groupDN);

    my $mail = EBox::Global->modInstance('mail');
    my $newAlias = $lhs."@".$rhs;
    $mail->{malias}->addGroupAlias($group, $newAlias);

    $self->{json}->{msg} = __x('Added alias {al}', al => $newAlias);
    $self->{json}->{mail} = $group->get('mail');
    $self->{json}->{aliases} =  $mail->{malias}->groupAliases($group);
    $self->{json}->{success} = 1;
}

1;
