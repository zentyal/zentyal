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

package EBox::CGI::Printers::AddPrinter;

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
	$self->{errorchain} = "Printers/AddPrinterUI";
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;

	$self->_requireParam('printername', __('Printer\'s name'));
	$self->_requireParam('method', __('Method'));
	#$self->_requireParamAllowEmpty('printerdesc',
					__('Printer description');

	my $printers = EBox::Global->modInstance('printers');
	my $name = $self->param('printername');
	my $method = $self->param('method');
	
	
	my $id = $printers->addPrinter($name, $method);

	$self->keepParam('printerid');
        $self->cgi()->param(-name=>'printerid', -value=>$id);
	if ($method eq 'network') {	
		$self->{chain} = "Printers/NetworkPrinterUI";
	} elsif ($method eq 'samba') {
		$self->{chain} = "Printers/SambaPrinterUI";
	} elsif ($method eq 'usb') {
		$self->{chain} = "Printers/USBPrinterUI";
	} elsif ($method eq 'parallel') {
		$self->{chain} = "Printers/ParallelPrinterUI";
	}
	
}

1;
