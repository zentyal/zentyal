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

package EBox::Users::CGI::AddGroup;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Users;
use EBox::Gettext;

sub new
{
	my $class = shift;
	my $self = $class->SUPER::new('template' => '/users/addgroup.mas', @_);
	bless($self, $class);
	return $self;
}

sub _process
{
	my $self = shift;
	my $users = EBox::Global->modInstance('users');

	my @args = ();

	$self->{params} = \@args;

    if ($self->param('add')) {
        $self->_requireParam('groupname', __('group name'));

        my $groupname = $self->param('groupname');
        my $comment = $self->unsafeParam('comment');

        my $group = EBox::Users::Group->create($groupname, $comment);

        $self->{redirect} = "Users/Tree/Manage";
    }
}

sub _print
{
    my ($self) = @_;

    $self->_printPopup();
}

sub _menu
{
}

sub _top
{
}

sub _footer
{
}

1;
