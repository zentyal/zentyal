# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::LdapUserImplementation;

use strict;
use warnings;

use base qw(EBox::LdapUserBase);

use EBox::Global;
use EBox::Gettext;


sub _create {
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}


sub _delGroupWarning($$) {
        my $self = shift;
        my $group = shift;
	
	my $users = EBox::Global->modInstance('users');
	
	unless ($users->_groupIsEmpty($group)) {
		return (__('This group contains users'));
	}

	return undef;
}

sub _includeLDAPSchemas
{
	my $users = EBox::Global->modInstance('users');

    return [] unless ($users->configured());

    return ['/etc/ldap/schema/passwords.schema'];
}

sub _includeLDAPAcls {
    my ($self) = @_;

	my $users = EBox::Global->modInstance('users');
    my $ldap = EBox::Ldap->instance();
    my $ldapconf = $ldap->ldapConf();

    return [] unless ($users->configured());

    my $passFormats = EBox::UsersAndGroups::Passwords::allPasswordFieldNames();
    my $attrs = join(',', @{$passFormats});

    my @acls = ("access to attrs=$passFormats\n" .
            "\tby dn.regex=\"" . $ldapconf->{'rootdn'} . "\" write\n" .
            "\tby self write\n" .
            "\tby * none\n");
}

1;
