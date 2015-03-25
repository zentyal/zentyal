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

package EBox::Samba::CGI::DeleteGroup;

use base 'EBox::CGI::ClientPopupBase';

use EBox::Global;
use EBox::Samba;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/samba/delgroup.mas', @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    $self->_requireParam('dn', 'dn');

    my @args;

    my $dn = $self->unsafeParam('dn');
    my $group = new EBox::Samba::Group(dn => $dn);

    # Forbid deletion of Domain Admins group
    if ($group->sid() =~ /^S-1-5-21-\d+-\d+-\d+-512$/) {
        push (@args, 'forbid' => 1);
    }

    if ($self->unsafeParam('delgroup')) {
        $self->{json} = { success => 0 };
        $group->deleteObject();
        $self->{json}->{success} = 1;
        $self->{json}->{redirect} = '/Samba/Tree/Manage';
    } else {
        # show confirmation dialog
        my $users = EBox::Global->getInstance()->modInstance('samba');
        push (@args, 'group' => $group);
        my $editable = $users->editableMode();
        my $warns = $users->allWarnings('group', $group);
        push (@args, warns => $warns);
        $self->{params} = \@args;
    }
}

1;
