#!/usr/bin/perl -w

# Copyright (C) 2012-2012 Zentyal S.L.
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

# Class: EBox::UsersAndGroups::OU
#
#   Organizational Unit, stored in LDAP
#

package EBox::UsersAndGroups::OU;

use strict;
use warnings;

use EBox::Global;
use EBox::UsersAndGroups;

use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;

use base 'EBox::UsersAndGroups::LdapObject';

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    return $self;
}

sub create
{
    my ($self, $dn) = @_;

    my $users = EBox::Global->modInstance('users');

    my %args = (
        attr => [
            'objectclass' => ['organizationalUnit'],
        ]
    );
    my $r = $self->_ldap->add($dn, \%args);

    my $res = new EBox::UsersAndGroups::OU(dn => $dn);
    return $res;
}


1;
