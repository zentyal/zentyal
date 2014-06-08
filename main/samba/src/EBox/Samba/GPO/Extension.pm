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
# Class: EBox::Samba::GPO::Extension
#
#   This is the base class for GPO Extensions to the GPO core protocol
#
package EBox::Samba::GPO::Extension;

use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::NotImplemented;
use EBox::Exceptions::MissingArgument;

sub new
{
    my ($class, %params) = @_;

    unless ($params{dn}) {
        throw EBox::Exceptions::MissingArgument('GPO DN');
    }
    my $gpo = new EBox::Samba::GPO(dn => $params{dn});
    unless ($gpo->exists()) {
        throw EBox::Exceptions::Internal(__x('GPO {x} not found.',
            x => $params{dn}));
    }

    my $self = {};
    $self->{gpo} = $gpo;
    bless ($self, $class);

    return $self;
}

sub gpo
{
    my ($self) = @_;

    unless ($self->{gpo}) {
        throw EBox::Exceptions::Internal(__('GPO not defined'));
    }
    return $self->{gpo};
}

sub toolExtensionGUID
{
    throw EBox::Exceptions::NotImplemented();
}

sub clientSideExtensionGUID
{
    throw EBox::Exceptions::NotImplemented();
}

1;
