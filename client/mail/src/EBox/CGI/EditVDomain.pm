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

package EBox::CGI::Mail::EditVDomain;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Mail;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title' => 'Edit virtual domain', 
		'template' => '/mail/editvdomains.mas', @_);
	$self->{domain} = "ebox-mail";	
	#$self->{redirect} = "Mail/VDomains";	
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	my $mail = EBox::Global->modInstance('mail');
 
	$self->_requireParam('vdomain', __('vdomain'));

	my $vdomain = $self->param('vdomain');
	my $components = $mail->{'vdomains'}->allVDomainsAddOns($vdomain);

	my $menu; 
	if (defined($self->param('menu'))) {
	  $menu = $self->param('menu'); 
	}
	else {
	  $menu = 0;
	}

	my @array = ();
	push(@array, 'vdomain' => $vdomain);

	push(@array, 'menu' => $menu);
	push(@array, 'components' => $components);

	if ($mail->mdQuotaAvailable()) {
	  push (@array, 'mdQuotaAvailable' => 1);

	}


	$self->{params} = \@array;
}

1;
