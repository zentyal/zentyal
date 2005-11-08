# Copyright (C) 2005  Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::CGI::Jabber::Index;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title'    => __('Jabber'),
				      'template' => 'jabber/index.mas',
				      @_);
	$self->{domain} = "ebox-jabber";
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	$self->{title} = __('Jabber');
	my $jabber = EBox::Global->modInstance('jabber');
	
		
	my @array = ();
	my $active = 'no';
	my $domain = '';
	my $ssl = 'No';
	my $external_connection = 0;
	if ($jabber->service()) {
	    $active = 'yes';
	}
	if ($jabber->domain) {
	    $domain = $jabber->domain;
	}
        $ssl = $jabber->ssl;
	if ($jabber->externalConnection eq 'true') {
	    $external_connection = 'yes';
	}

	push (@array, 'active' => $active);
	push (@array, 'domain' => $domain);
	push (@array, 'ssl' => $ssl);
	push (@array, 'external_connection' => $external_connection);

	$self->{params} = \@array;
}

1;
