# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::JabberLdapUser;

use strict;
use warnings;


use EBox::Sudo qw( :all );
use EBox::Global;
use EBox::Ldap;
use EBox::Network;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Gettext;

use constant SCHEMAS => ('/etc/ldap/schema/jabber.schema');

use base qw(EBox::LdapUserBase);

sub _userAddOns
{
        my ($self, $username) = @_;

	my @args;
	my $args = { 'active'   => 'yes',
		     'is_admin' => '1' };
	return { path => '/jabber/jabber.mas',
		 params => $args };
}

sub _includeLDAPSchemas
{
        my $self = shift;
	my @schemas = SCHEMAS;
	return \@schemas;
}

1;
