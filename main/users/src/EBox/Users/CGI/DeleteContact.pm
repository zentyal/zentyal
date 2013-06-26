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

package EBox::Users::CGI::DeleteContact;

use base 'EBox::CGI::ClientPopupBase';

use EBox::Global;
use EBox::Users;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/users/delcontact.mas', @_);
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
    my $contact = new EBox::Users::Contact(dn => $dn);

    my $editable = $users->editableMode();

    push(@args, 'contact' => $contact);
    push(@args, 'slave' => not $editable);

    my $delcontact;

    if ($self->param('cancel')) {
        $self->{redirect} = 'Users/Tree/Manage';
    } elsif ($self->unsafeParam('delcontactforce')) {
        $delcontact = 1;
    } elsif ($self->unsafeParam('delcontact')) {
        my $contact = new EBox::Users::Contact(dn => $dn);
        $delcontact = not $self->_warnUser('contact', $contact);
    }

    if ($delcontact) {
        $self->{json} = { success => 0 };
        my $contact = new EBox::Users::Contact(dn => $dn);
        $contact->deleteObject();
        $self->{json}->{success} = 1;
        $self->{json}->{redirect} = '/Users/Tree/Manage';
    }

    $self->{params} = \@args;
}

sub _warnContact
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
