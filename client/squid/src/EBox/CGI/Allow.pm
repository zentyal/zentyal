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

package EBox::CGI::Squid::Allow;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	$self->{domain} = "ebox-squid";
	$self->{redirect} = "Squid/AllowedDomains";
	$self->{errorchain} = "Squid/AllowedDomains";
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	my $squid = EBox::Global->modInstance('squid');

	$self->_requireParam("domain_name", __('domain name'));
	$self->_requireParam("action", __('action'));

	my $domain = $self->param("domain_name");
	my $action = $self->param("action");
	
	if ($action eq 'add'){
		$squid->addAllowedDomain($domain);
	} elsif ($action eq 'delete')  {
		$squid->removeAllowedDomain($domain);
	}

}
1;
