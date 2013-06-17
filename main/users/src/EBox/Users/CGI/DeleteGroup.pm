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

package EBox::Users::CGI::DeleteGroup;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Users;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/users/delgroup.mas', @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');

    $self->{'title'} = __('Users');

    my @args = ();

    $self->_requireParam('dn', 'dn');

    my $dn = $self->unsafeParam('dn');
    my $group = new EBox::Users::Group(dn => $dn);

    my $editable = $users->editableMode();

    push(@args, 'group' => $group);
    push(@args, 'slave' => not $editable);

    my $delgroup;

    if ($self->param('cancel')) {
        $self->{redirect} = 'Users/Tree/ManageUsers';
    } elsif ($self->param('delgroupforce')) {
        $delgroup = 1;
    } elsif ($self->unsafeParam('delgroup')) {
        my $group = new EBox::Users::Group(dn => $dn);
        $delgroup = not $self->_warnUser('group', $group);
    }

    if ($delgroup) {
        my $group = new EBox::Users::Group(dn => $dn);
        $group->deleteObject();
        $self->{msg} = __('Group removed successfully');
        $self->{redirect} = 'Users/Tree/ManageUsers';
    }

    $self->{params} = \@args;
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

sub _warnUser
{
    my ($self, $object, $ldapObject) = @_;

    my $usersandgroups = EBox::Global->modInstance('users');
    my $warns = $usersandgroups->allWarnings($object, $ldapObject);

    if (@{$warns}) { # If any module wants to warn user
         $self->{template} = 'users/del.mas';
         $self->{redirect} = undef;
         my @array = ();
         push(@array, 'object' => $object);
         push(@array, 'name'   => $ldapObject);
         push(@array, 'data'   => $warns);
         $self->{params} = \@array;
         return 1;
    }

    return undef;
}

1;
