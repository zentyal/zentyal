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

#
# Class: EBox::Samba::GPO::ScriptsComputer
#
package EBox::Samba::GPO::ScriptsComputer;

use base 'EBox::Samba::GPO::Scripts';

sub _scope
{
    my ($self) = @_;

    return 'MACHINE';
}

sub toolExtensionGUID
{
    my ($self) = @_;

    return '{40B6664F-4972-11D1-A7CA-0000F87571E3}';
}

sub clientSideExtensionGUID
{
    my ($self) = @_;

    return '{42B5FAAE-6536-11D2-AE5A-0000F87571E3}';
}

1;
