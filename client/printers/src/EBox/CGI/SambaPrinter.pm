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

package EBox::CGI::Printers::SambaPrinter;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	$self->{domain} = 'ebox-printers';
	$self->{errorchain} = "Printers/SambaPrinterUI";
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;

	$self->_requireParam('printerid', __('Printer'));
	$self->_requireParam('resource', __('Shared resource'));
	$self->_requireParam('auth', __('Authentication'));
	my $id = $self->param('printerid');
	my $resource = $self->param('resource');
	my $auth = $self->param('auth');
	
	my $user = "";
	my $passwd = "";
	if ($auth eq 'user') {
		$self->_requireParam('user', __('User'));
		$self->_requireParam('passwd', __('Password'));
		$user = $self->param('user');
		$passwd = $self->param('passwd');
	}
	my $printers = EBox::Global->modInstance('printers');
	
 	$printers->setSambaPrinter($id, $resource, $auth, $user, $passwd);
	if ($self->param('sambaconfui')) {	
		$self->keepParam('printerid');
		$self->{chain} = "Printers/ManufacturerUI";
	 } elsif ($self->param('manageprinterui')) {
	         $self->{chain} = "Printers/ManagePrinterUI";
	         $self->keepParam('selected');
	 }
				   
				   
	
}

1;
