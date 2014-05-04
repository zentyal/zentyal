# Copyright (C) 2005-2007 Warp Networks S.L.
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

package EBox::LdapUserImplementation;

use base qw(EBox::LdapUserBase);

use EBox::Global;
use EBox::Gettext;

sub _create
{
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub _delGroupWarning
{
    my ($self, $group) = @_;

    if (@{$group->members()}) {
        return (__('This group contains members'));
    }

    return undef;
}

sub schemas
{
    return [
        EBox::Config::share() . '/zentyal-users/passwords.ldif',
        EBox::Config::share() . '/zentyal-users/quota.ldif',
    ];
}

sub acls
{
    my $users = EBox::Global->modInstance('users');
    return [];
}

sub indexes
{
    return ['uid', 'uidNumber', 'cn', 'ou', 'gidNumber', 'uniqueMember', 'krb5PrincipalName'];
}

# Method: hiddenOUs
#
#   Returns the list of OUs to hide on the UI
#
sub hiddenOUs
{
    return [ 'Builtin', 'Kerberos' ];
}

1;
