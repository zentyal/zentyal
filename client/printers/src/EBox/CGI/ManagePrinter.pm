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

package EBox::CGI::Printers::ManagePrinter;

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
	$self->{errorchain} = "Printers/ShowPrintersUI";
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;

	$self->_requireParam('printerid', __('Printer'));

	my $printers = EBox::Global->modInstance('printers');
	my $id = $self->param('printerid');
	
	$self->keepParam('printerid');
        $self->cgi()->param(-name=>'printerid', -value=>$id);
	if (defined($self->param('delete'))) {	
		$self->{chain} = "Printers/DeleteUI";
	} elsif (defined($self->param('delforce'))){
		$printers->removePrinter($id);
		$self->{msg} = __('The printer has been deleted successfully');
		$self->{chain} = "Printers/ShowPrintersUI";
	} elsif (defined($self->param('edit'))) {
		$self->{chain} = "Printers/ManagePrinterUI";
	} elsif (defined($self->param('cancel'))) {	
		$self->{chain} = "Printers/ShowPrintersUI";
	}
}

1;
