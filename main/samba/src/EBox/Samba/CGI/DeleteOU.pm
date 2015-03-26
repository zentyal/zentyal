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

package EBox::Samba::CGI::DeleteOU;

use base 'EBox::CGI::ClientPopupBase';

use EBox::Gettext;
use EBox::Global;

use Perl6::Junction qw(any);

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/samba/delou.mas', @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    my $usersMod = EBox::Global->modInstance('samba');

    $self->{'title'} = __('Users');

    my @args = ();

    $self->_requireParam('dn', 'dn');

    my $dn = $self->unsafeParam('dn');
    my $ou = $usersMod->ouClass()->new(dn => $dn);
    my $editable = $usersMod->editableMode();

    my $name = $ou->name();
    if ($name eq any (qw(Users Groups Computers))) {
        push (@args, 'forbid' => 1);
    }

    push (@args, 'dn' => $dn);

    my $delou;

    if ($self->param('cancel')) {
        $self->{redirect} = 'Samba/Tree/Manage';
    } elsif ($self->param('delouforce')) {
        $delou = 1;
    } elsif ($self->unsafeParam('delou')) {
        $delou = not $self->_warnUser('ou', $ou);
    }

    if ($delou) {
        $self->{json} = { success => 0 };
        $ou->deleteObject();
        $self->{json}->{success} = 1;
        $self->{json}->{redirect} = '/Samba/Tree/Manage';
    }

    $self->{params} = \@args;
}

sub _warnUser
{
    my ($self, $object, $ldapObject) = @_;

    my $usersMod = EBox::Global->modInstance('samba');
    my $warns = $usersMod->allWarnings($object, $ldapObject);

    if (@{$warns}) { # If any module wants to warn user
         $self->{template} = 'samba/del.mas';
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
