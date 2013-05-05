# Copyright (C) 2012-2013 Zentyal S.L.
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
#
# Class: EBox::SyncFolders::Provider
#
#   This module exposes some system paths to be synchronized with an
#   external provider
#
use strict;
use warnings;

package EBox::SyncFolders::Provider;

use EBox::Exceptions::NotImplemented;
use Perl6::Junction qw(any);

sub new
{
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

# Method: syncFolders
#
#   Return a list of folders to be synchronized to/from an external
#   file store.
#
# Returns:
#
#   array ref to a list of SyncFolders::Folder
#
sub syncFolders
{
    my ($self) = @_;
    throw EBox::Exceptions::NotImplemented('syncFolders', ref($self));
}

# Method: recoveryDomainName
#
#   Printable name for the disaster recovery domain, to be implemented
#   in providers with 'recovery' sync folders
#
# Returns:
#
#   string with the name
#
sub recoveryDomainName
{
    return undef;
}

1;
