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

package EBox::CGI::Printers::ManagePrinterUI;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title'    => __('Manage printer'),
				      'template' => 'printers/printer.mas',
				      @_);
	$self->{domain} = 'ebox-printers';
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;

        $self->_requireParam('printerid', __('Printer'));
        my $id = $self->param('printerid');

	my $selected = $self->param('selected');

        if  ((not defined($selected)) or $self->param('setdrvopts')) {
		$selected = 'details';
	}

	my $printers = EBox::Global->modInstance('printers');
	my $info = $printers->_printerInfo($id);
	my @tabs = ();
	push(@tabs, {'link' => 'details', 'name' => __("Printer details")});
	push(@tabs, {'link' => 'drvopts', 'name' => __("Driver Options")});
	push(@tabs, {'link' => 'config', 'name' => __("Configuration options")});
	push(@tabs, {'link' => 'jobs', 'name' => __("Jobs Queue")});

	my @array;
        push (@array, 'printerid' => $id);
	push (@array, 'name' => $info->{'name'});
	push (@array, 'manufacturer' => $info->{'manufacturer'});
	push (@array, 'model' => $info->{'model'});
	push (@array, 'driver' => $printers->driver($id));
	push (@array, 'methconf' => $printers->methodConf($id) );
	push (@array, 'opts' => $printers->driverOptions($id));
	push (@array, 'jobs' => $printers->printerJobs($id, 0));
	push (@array, 'tabs' => \@tabs);
	push (@array, 'selected' => $selected);
	if ($printers->methodConf($id)->{'method'} eq 'usb') {
		push (@array, 'devices' => $printers->usbDevices());
	} elsif ($printers->methodConf($id)->{'method'} eq 'parallel') {
		push (@array, 'devices' => $printers->parallelDevices());
	}
	$self->{params} = \@array;
}

1;
