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

package EBox::Users::CGI::AddOU;

use base 'EBox::CGI::ClientPopupBase';

use EBox::Global;
use EBox::Users::OU;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/users/addou.mas', @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my $self = shift;

    my @args;

    if ($self->param('add')) {
        $self->{json} = { success => 0 };
        $self->_requireParam('ou', __('OU name'));
        my $ou = $self->param('ou');

        my $users = EBox::Global->modInstance('users');
        # FIXME: We should support nested OUs!
        my $parent = $users->defaultNamingContext();

        EBox::Users::OU->create($ou, $parent);

        $self->{json}->{success} = 1;
        $self->{json}->{redirect} = '/Users/Tree/Manage';
    }
}

1;
