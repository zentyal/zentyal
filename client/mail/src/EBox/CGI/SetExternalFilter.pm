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

package EBox::CGI::Mail::SetExternalFilter;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Mail;
use EBox::Gettext;


sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title' => 'Mail',
				      @_);
	$self->{redirect} = "Mail/Index?menu=filter";
	$self->{domain} = 'ebox-mail';
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	my $mail = EBox::Global->modInstance('mail');
	$self->{redirect} = "Mail/Index?menu=filter";
	$self->{errorchain} = "Mail/Index";
	$self->keepParam('menu');

	my $filter = $self->param('filter');
	my $filterActive = ($filter ne 'none'); 

	$mail->setService('filter', $filterActive);
	EBox::debug("filter  $filter active $filterActive");
	
	if ($filterActive) {
	  $mail->setExternalFilter($filter);
	  

	  if ($filter eq 'custom') {
	    $self->_requireParam('ipfilter');
	    my $ipfilter = $self->param('ipfilter');
	    $self->_requireParam('portfilter');
	    my $portfilter = $self->param('portfilter');
	    $self->_requireParam('fwport');
	    my $fwport = $self->param('fwport');

	    $mail->setIPFilter($ipfilter);
	    $mail->setPortFilter($portfilter);
	    $mail->setFWPort($fwport);
	  }

	}
}


1;
