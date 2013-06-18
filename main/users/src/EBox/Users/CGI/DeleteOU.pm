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

package EBox::Users::CGI::DeleteOU;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
use EBox::Users::OU;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/users/delou.mas', @_);
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
    my $ou = new EBox::Users::OU(dn => $dn);

    my $editable = $users->editableMode();

    push(@args, 'ou' => $ou);
    push(@args, 'slave' => not $editable);

    my $delou;

    if ($self->param('cancel')) {
        $self->{redirect} = 'Users/Tree/ManageUsers';
    } elsif ($self->param('delouforce')) {
        $delou = 1;
    } elsif ($self->unsafeParam('delou')) {
        my $ou = new EBox::Users::Group(dn => $dn);
        $delou = not $self->_warnUser('ou', $ou);
    }

    if ($delou) {
        my $ou = new EBox::Users::Group(dn => $dn);
        $ou->deleteObject();
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

    my $users = EBox::Global->modInstance('users');
    my $warns = $users->allWarnings($object, $ldapObject);

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
