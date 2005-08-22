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

package EBox::MailFilterLdap;

use strict;
use warnings;

use EBox::Sudo qw( :all );
use EBox::Global;
use EBox::Ldap;
use EBox::Gettext;

# LDAP schema
use constant SCHEMAS		=> ( '/etc/ldap/schema/eboxfilter.schema', 
	'/etc/ldap/schema/amavis.schema');

use base qw(EBox::LdapUserBase EBox::LdapVDomainBase);

sub new 
{
	my $class = shift;
	my $self  = {};
	$self->{ldap} = new EBox::Ldap;
	bless($self, $class);
	return $self;
}

sub _addVDomain() {
}

sub _delVDomain() {
}

sub _modifyVDomain() {
}

sub _delVDomainWarning() {
}

sub _vdomainAddOns() {
	my $pages = [
		{ 
			'name' => 'General Filter Settings',
			'path' => 'mailfilter/fgeneral.mas',
			'params' => 'foobar',
	   },
		{
			'name' => 'Filter Restrictions',
			'path' => 'mailfilter/frestrict.mas',
			'params' => 'foobar',
		},
		{
			'name' => 'Filter White/Black Lists',
			'path' => 'mailfilter/flists.mas',
			'params' => 'foobar',
		},
	];
	
	return $pages;
}

sub _includeLDAPSchemas {
	my $self = shift;
	my @schemas = SCHEMAS;

	return \@schemas;
}

1;
