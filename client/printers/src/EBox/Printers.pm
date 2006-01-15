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

package EBox::Printers;

use strict;
use warnings;

use base qw(EBox::GConfModule EBox::FirewallObserver EBox::LogObserver);

use EBox::Gettext;
use EBox::Config;
use EBox::Service;
use EBox::Summary::Module;
use EBox::Menu::Folder;
use EBox::Menu::Item;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::External;
use EBox::Validate qw( :all );
use EBox::Sudo qw( :all );
use EBox::PrinterFirewall;
use EBox::PrinterLogHelper;
use Foomatic::DB;
use Net::CUPS::Printer;
use Storable;

use constant PPDBASEPATH      	=> '/usr/share/ppd/';
use constant MAXPRINTERLENGHT 	=> 10;
use constant SUPPORTEDMETHODS 	=> ('usb', 'parallel', 'network', 'samba');
use constant CUPSPRINTERS     	=> '/etc/cups/printers.conf';
use constant CUPSPPD 		=> '/etc/cups/ppd/';

sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'printers', 
					  domain => 'ebox-printers' );
	bless($self, $class);
	return $self;
}

sub domain
{
	return 'ebox-printers';	
}

sub rootCommands
{
	my $self = shift;
	my @array;
	push(@array, $self->rootCommandsForWriteConfFile(CUPSPRINTERS));
	push(@array, "/bin/mv " . EBox::Config::tmp . "* " . CUPSPPD ."*");

	return @array;

}

sub firewallHelper
{
        my $self = shift;
        if ($self->service) {
                return new EBox::PrinterFirewall();
        }
        return undef;
}

sub _setCupsConf
{
	my $self = shift;

	my @conf;
	my @idprinters = $self->all_dirs("printers");
	for my $dirid (@idprinters){
		my $id = $dirid;
		$id =~  s'.*/'';
		unless ($self->_printerConfigured($id)){
			$self->removePrinter($id);
			next;
		}
		$self->_setDriverOptionsToFile($id);
		my $printer = $self->_printerInfo($id);
		$printer->{location} = $self->_location($id);
		push (@conf, $printer );
	}

	my @array;
	push(@array, 'printers' => \@conf);
	$self->writeConfFile(CUPSPRINTERS, "printers/printers.conf", \@array);
}

sub isRunning 
{
	EBox::Service::running('cups');
}

sub _doDaemon
{
        my $self = shift;

	# So far, this module depends on samba module.
	my $samba = EBox::Global->modInstance('samba');
	my $service = $samba->service();

        if ($service and $self->isRunning) {
                EBox::Service::manage('cups','restart');
        } elsif ($service) {
                EBox::Service::manage('cups','start');
        } elsif ($self->isRunning) {
                EBox::Service::manage('cups','stop');
        }
}

sub _regenConfig
{
	my $self = shift;
	$self->_setCupsConf();
	$self->_doDaemon();
}

sub summary
{
	my $self = shift;
	return undef;
}

sub statusSummary
{
        my $self = shift;

	my $smbrun = 1;
	if (_checkSambaInstalled()) {
                my $samba = EBox::Global->modInstance('samba');
		$smbrun = $samba->isRunning;
        }
        return new EBox::Summary::Status('printers', __('Printer sharing'),
                                ($self->isRunning and $smbrun), $self->service);
}


#   Function: setService 
#
#       Sets the printer service.
#
#   Parameters:
#
#       enabled - boolean. True enable, undef disable
#
sub setService # (enabled)
{
        my ($self, $active) = @_;

        ($active and $self->service) and return;
        (!$active and !$self->service) and return;
        $self->set_bool("active", $active);

	if (_checkSambaInstalled()) {
		my $samba = EBox::Global->modInstance('samba');
		$samba->setPrinterService($active);
	}

}

#   Function: service 
#
#       Returns if the printer service is enabled  
#
#   Returns:
#
#       boolean - true if enabled, otherwise undef      
#
sub service
{
        my $self = shift;
        return $self->get_bool("active");
}


sub manufacturers
{
	shift;
	
	my $db = new Foomatic::DB;
	my @makes = $db->get_makes();
	return \@makes;
}

sub manufacturerModels($$)
{
	my $self = shift;
	my $id = shift;

	my $db = new Foomatic::DB;
	my $manufacturer = $self->manufacturer($id);
	my @models = grep($self->_checkModelHasDriver($id, $manufacturer, $_), 
			$db->get_models_by_make($manufacturer));
	return \@models;
}

sub _checkModelHasDriver
{
        my $self = shift;
        my $id = shift;
        my $manufacturer = shift;
        my $printer = shift;
       
	$printer =~ s/\s/_/g;
        my $dir = PPDBASEPATH . $manufacturer . "/";
        foreach my $file (`ls $dir`) {
                chomp($file);
                return 1 if ($file =~ m{$manufacturer-$printer.*\.ppd\.gz});
        }

        return undef;
}

sub _printerFromManuModel($$$)
{
	shift;
	my $maker = shift;
	my $model = shift;
	
	my $db = new Foomatic::DB;
	return $db->get_printer_from_make_model($maker, $model);
}	

sub _printerIdDriver($$$)
{
	my $self = shift;
	my $id = shift;
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataExists(
					'data'  => __('Printer'),
					'value' => "$id");
	}

	my $maker = $self->manufacturer($id);
	my $model = $self->model($id);
	my $db = new Foomatic::DB;
	return $db->get_printer_from_make_model($maker, $model);
}

sub driversForPrinter($$)
{
	my $self = shift;
	my $id = shift;
	
	my $printer = $self->_printerIdDriver($id);
	
	my $db = new Foomatic::DB;
	my @drivers = grep(! /^(gimp.*)|(hpdj)/, 
			$db->get_drivers_for_printer($printer));
	if (@drivers) {
		return \@drivers;	
	} else {
		return [];
	}
}


sub menu
{
	my ($self, $root) = @_;
	
	my $folder = new EBox::Menu::Folder('name' => 'Printers',
					    'text' => __('Printers'));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/AddPrinterUI',
					  'text' => __('Add printer')));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/AddPrinter',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/CancelJob',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/DeleteUI',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/DriverUI',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/DrvoptsUI',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/Enable',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/ManagePrinter',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/ManagePrinterUI',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/Manufacturer',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/ManufacturerUI',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/Model',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/ModelUI',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/NetworkPrinter',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/NetworkPrinterUI',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/ParallelPrinterUI',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/SambaPrinter',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/SambaPrinterUI',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/USBPrinterUI',
					  'text' => ''));

	$folder->add(new EBox::Menu::Item('url' => 'Printers/USBPrinter',
					  'text' => ''));

	if (@{$self->printers()}){
		$folder->add(new EBox::Menu::Item(
			'url' => 'Printers/ShowPrintersUI',
		  	'text' => __('Manage printers')));
	}

	$root->add($folder);
}

sub _printerNameExists($$)
{
	my ($self, $name) = @_;
	
	my @idprinters = $self->all_dirs("printers");
	foreach my $dirid (@idprinters) {
		my $idname = $self->get_string("$dirid/name");
		return 1 if ($idname eq $name);
	}	
	return undef;
}

sub _printerIdExists($$)
{
	my ($self, $id) = @_;
	defined($id) or return undef;
	return $self->dir_exists("printers/$id");
}

sub _printerInfo($$) 
{
	my ($self, $id) = @_;
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataExists(
					'data'  => __('Printer'),
					'value' => "$id");
	}

	my @idprinters = $self->all_dirs("printers");
	return  $self->hash_from_dir("printers/$id");
}

sub _printerConfigured($$) 
{
	my ($self, $id) = @_;
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataExists(
					'data'  => __('Printer'),
					'value' => "$id");
	}

	my $printer = $self->_printerInfo($id);

	return ($printer->{'configured'});
}

sub _setPrinterConfigured($$$)
{
	my $self = shift;
	my $id = shift;
	my $state = shift;

	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataExists(
					'data'  => __('Printer'),
					'value' => "$id");
	}

	return if ($state eq $self->_printerConfigured($id));
	$self->set_bool("printers/$id/configured", $state);
}

sub printers
{
	my $self = shift;

	my @printers;
	unless ($self->dir_exists("printers")){
		return \@printers;
	}
	
	my @idprinters = $self->all_dirs("printers");
	foreach my $dirid (@idprinters) {
		my $id = $dirid;
		$id =~  s'.*/'';
		next unless ($self->_printerConfigured($id));
		my $name = $self->get_string("$dirid/name");
		my $info = $self->manufacturer($id) . " " . $self->model($id);
		push(@printers, 
			{ 'id' => $id, 'name' => "$name" , 'info' => "$info" });
	}
	return \@printers;	
}

# Method: cleanTempPrinters
#
#  	Remove those printers which have not been fully configured	
#
# 	
sub cleanTempPrinters
{
	my $self = shift;

	return unless ($self->dir_exists("printers"));
	foreach my $dirid ($self->all_dirs("printers")) {
		my $id = $dirid;
		$id =~  s'.*/'';
		unless ($self->_printerConfigured($id)) {
			$self->removePrinter($id);
		}
	}
}

sub removePrinter # (id)
{
	my $self = shift;
	my $id = shift;
	
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataExists(
					'data'  => __('Printer'),
					'value' => "$id");
	}
	
	$self->_removeCacheDrvOptions($id);
	
	if (_checkSambaInstalled() and $self->_printerConfigured($id)) {
		my $samba = EBox::Global->modInstance('samba');
		my $info = $self->_printerInfo($id);
		$samba->delPrinter($info->{'name'});
	}
	$self->delete_dir("printers/$id");
}

sub addPrinter($$$)
{
	my ($self, $name, $method) = @_;
	unless (_checkPrinterName($name)) {
                throw EBox::Exceptions::External
                        __("The printer's name contains characters not valid." .
                        "Only alphanumeric characters are allowed");	
	}
	unless (grep(/^$method$/, SUPPORTEDMETHODS)) {
		throw EBox::Exceptions::InvalidData('data'  => __('Method'),
						    'value' => "$method");
	}
	if  ($self->_printerNameExists($name)) {
		throw EBox::Exceptions::DataExists(
					'data'  => __('Name'),
					'value' => "$name");
	}
	if (_checkSambaInstalled()) {	
		my $samba = EBox::Global->modInstance('samba');
		my $rsr = $samba->existsShareResource($name);
		if ($rsr) {
			throw EBox::Exceptions::External(
			  __('The given name is alreaday used as ') . $rsr);
		}
	}
	
	my $id = $self->get_unique_id('p', 'printers');
	$self->set_string("printers/$id/name", $name);
	$self->set_bool("printers/$id/configured", undef);
	$self->set_string("printers/$id/conf/method", $method);

	return $id;
}

sub _location ($$)
{
	my $self = shift;
	my $id = shift;
	
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}
	unless ($self->_printerConfigured($id)) {
		throw EBox::Exceptions::External(__('Printer not configured'));
	}
	my $conf = $self->methodConf($id);

	my $location;
	if ($conf->{method} eq 'network'){
		$location = "socket://" . $conf->{host} . ":" . $conf->{port};
	} elsif ($conf->{method} eq 'samba'){
		my $smburi = $conf->{resource};
		if ($conf->{auth} eq 'guest') {
			$smburi = "guest:@".$smburi;
		} elsif ($conf->{auth} eq 'anonymous') {
		} elsif ($conf->{auth} eq 'user'){
			$smburi = $conf->{user} . ":" . $conf->{passwd} . 
				  "@" . "$smburi";
		}
		$location = "smb://$smburi";
	} elsif ($conf->{method} eq 'usb') {
		$conf->{dev} =~ s/usb/lp/;
		$location = "usb:/dev/usb/" . $conf->{dev};
	} elsif ($conf->{method} eq 'parallel') {
		$location = "parallel:/dev/" . $conf->{dev};
	}
	return $location;	
}

sub methodConf($$)
{
	my $self = shift;;
	my $id = shift;

	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}
	
	unless ($self->dir_exists("printers/$id/conf")){
		return undef;
	}
	return $self->hash_from_dir("printers/$id/conf");
}

sub setMethod($$$)
{
	my $self = shift;;
	my $id = shift;
	my $method = shift;;	

	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}
	unless (grep(/^$method$/, SUPPORTEDMETHODS)) {
		throw EBox::Exceptions::InvalidData('data'  => __('Method'),
						    'value' => "$method");
	}
	
	return if ($self->get_string("printers/$id/method") eq $method);
	if ($self->dir_exists("printers/$id/conf")){
		$self->delete_dir("printers/$id/conf");
	}
	$self->set_string("printers/$id/conf/method", $method);
}

sub setUSBPrinter($$$)
{
	my $self = shift;
	my $id = shift;
	my $dev = shift ;
	
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}
	
	unless ($dev =~ /^usb\d$/) {
		throw EBox::Exceptions::InvalidData
			('data' => __('Device'), 'value' => $dev);
	}
	my $method = $self->methodConf($id);
	unless ($method->{'method'} eq 'usb') {
		throw EBox::Exceptions::External(
				__("It is not a usb printer"));
	}
	
	unless ($self->get_string("printers/$id/conf/dev" eq $dev)){
		$self->set_string("printers/$id/conf/dev", $dev);
	}
}

sub setParallelPrinter($$$)
{
	my $self = shift;
	my $id = shift;
	my $dev = shift ;
	
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}
	
	unless ($dev =~ /^lp\d$/) {
		throw EBox::Exceptions::InvalidData
			('data' => __('Device'), 'value' => $dev);
	}
	my $method = $self->methodConf($id);
	unless ($method->{'method'} eq 'parallel') {
		throw EBox::Exceptions::External(
				__("It is not a parallel printer"));
	}
	
	unless ($self->get_string("printers/$id/conf/dev" eq $dev)){
		$self->set_string("printers/$id/conf/dev", $dev);
	}
}

sub setNetworkPrinter($$$)
{
	my $self = shift;
	my $id = shift;
	my $ip = shift ;
	my $port = shift;
	
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}
	
	checkIP($ip, __('IP'));
	checkPort($port, __('Port'));

	my $method = $self->methodConf($id);
	unless ($method->{'method'} eq 'network') {
		throw EBox::Exceptions::External(
				__("It is not a network printer"));
	}
	
	unless ($self->get_string("printers/$id/conf/host" eq $ip)){
		$self->set_string("printers/$id/conf/host", $ip);
	}
	unless ($self->get_int("printers/$id/conf/port") eq $port){
		$self->set_int("printers/$id/conf/port", $port);
	}
	
}

sub setSambaPrinter # (id, resource, method, user, passwd)
{
	my $self = shift;
	my $id = shift;
	my $rsrc = shift;
	my $auth = shift;
	my $user= shift ;
	my $passwd = shift;
	
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}
	
	my $method = $self->methodConf($id);
	unless ($method->{'method'} eq 'samba') {
		throw EBox::Exceptions::External(
				__("It is not a samba printer"));
	}
	
	unless ($self->get_string("printers/$id/conf/resource" eq $rsrc)){
		$self->set_string("printers/$id/conf/resource", $rsrc);
	}
	unless ($self->get_string("printers/$id/conf/auth" eq $auth)){
		$self->set_string("printers/$id/conf/auth", $auth);
	}
	unless ($self->get_string("printers/$id/conf/user") eq $user){
		$self->set_string("printers/$id/conf/user", $user);
	}
	unless ($self->get_string("printers/$id/conf/passwd") eq $passwd){
		$self->set_string("printers/$id/conf/passwd", $passwd);
	}
	
}

sub _manufacturerExists($$)
{
	my $self = shift;
	my $maker = shift;

	return 1;
	for my $manufacturer (@{$self->manufacturers()}){
		return 1 if ("$maker" eq "$manufacturer");
	}

	return undef;
}

sub manufacturer($$)
{
	my $self = shift;
	my $id = shift;
	
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}

	return $self->get_string("printers/$id/manufacturer");	
}

sub setManufacturer($$$)
{
	my $self = shift;
	my $id = shift;
	my $maker = shift;
	
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}
	unless ($self->_manufacturerExists($id)) {
		throw EBox::Exceptions::DataNotFound(
			'data'  => __('Manufacturer'), 'value' => "$maker");
	}
	
	$self->set_bool("printers/$id/raw", undef);
	return if ($self->manufacturer($id) eq "$maker");

	$self->set_string("printers/$id/manufacturer", $maker);
	$self->_setPrinterConfigured($id, undef);
	if ($self->dir_exists("printers/$id/drvopts")){
		$self->delete_dir("printers/$id/drvopts");
	}

	
}

sub model($$)
{
	my $self = shift;
	my $id = shift;
	
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}

	return $self->get_string("printers/$id/model");	
}

sub setModel($$$)
{
	my $self = shift;
	my $id = shift;
	my $model = shift;
	
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}
	unless ($self->_manufacturerExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Model'),
						     'value' => "$model");
	}
	
	$self->set_bool("printers/$id/raw", undef);
	return if ($self->model($id) eq "$model");

	$self->set_string("printers/$id/model", $model);
	$self->_setPrinterConfigured($id, undef);
	if ($self->dir_exists("printers/$id/drvopts")){
		$self->delete_dir("printers/$id/drvopts");
	}

}


sub driver($$)
{
	my $self = shift;
	my $id = shift;
	
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}

	return $self->get_string("printers/$id/driver");	
}

sub setDriver($$$)
{
	my $self = shift;
	my $id = shift;
	my $driver = shift;
	
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}
	unless ($self->_manufacturerExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Model'),
						     'value' => "$driver");
	}
	
	$self->set_bool("printers/$id/raw", undef);
	return if ($self->driver($id) eq "$driver");

	$self->set_string("printers/$id/driver", $driver);
	$self->_setPrinterConfigured($id, undef);
	if ($self->dir_exists("printers/$id/drvopts")){
		$self->delete_dir("printers/$id/drvopts");
	}

}

sub driverArgs($$) 
{
	my $self = shift;
	my $id = shift;

	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}
	
	my $driver = $self->driver($id);
	my $printer = $self->model($id);
	my $manufacturer = $self->manufacturer($id);

	my $printerid = $self->_printerFromManuModel($manufacturer, $printer);
	$printerid or return {};
	
	my $db = new Foomatic::DB;
	my $dat = $db->getdat($driver, $printerid);

	my @args = keys %{$dat->{args_byname}};
	return \@args;
}

sub driverOptions($$)
{
	my $self = shift;
	my $id = shift;

	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}

	my $driveropts = $self->_driverOptionsFile($id);
	if ($self->_printerConfigured($id)) {
		if ($self->dir_exists("printers/$id/drvopts")){
			my $opts = $self->hash_from_dir("printers/$id/drvopts");
			for my $key (keys %{$opts}){
				$driveropts->{$key}->{value} = $opts->{$key};
			}
			
		}
	}

	return $driveropts;
}

sub setDriverOptions($$$)
{
	my $self = shift;
	my $id  = shift;
	my $defaults = shift;
	
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}

	$self->_checkDriverOpts($id, $defaults);
	my $drvopts = undef;
	if ($self->dir_exists("printers/$id/drvopts")) {
		$drvopts = $self->hash_from_dir("printers/$id/drvopts");
	}
		
	for my $key (keys %{$defaults}) {
		my $value = $defaults->{$key};
		next if ($drvopts and ("$drvopts->{$key}" eq $value));
		$self->set_string("printers/$id/drvopts/$key", $value);
	}

	$self->_setPrinterConfigured($id, 1);
	if (_checkSambaInstalled()) {
		my $samba = EBox::Global->modInstance('samba');
		my $info = $self->_printerInfo($id);
		$samba->addPrinter($info->{'name'});
	}
}

sub _checkDriverOpts # (id, options)
{
	my $self = shift;
	my $id = shift;
	my $opts = shift;

	my $fileopts = $self->_driverOptionsFile($id);
	
	for my $opt (keys %{$opts}) {
		unless(defined($fileopts->{$opt})) {
			throw EBox::Exceptions::External(
				$opt . " " . __('is not a valid option'));
		}
		
		my $type = $fileopts->{$opt}->{'type'};
		my $ok;
		if ($type eq 'enum') {
			for my $valid (@{$fileopts->{$opt}->{options}}) {
				if (defined($valid->{$opts->{$opt}})) {
					$ok = 1;
					last;
				}
			}
		} elsif (($type eq 'int') or ($type eq 'float')) {
			my $value = $opts->{$opt};
			if ($value =~ /\d+(\.\d+)?/) {
				if (($value >=  $fileopts->{$opt}->{'min'}) and  
				    ($value <= $fileopts->{$opt}->{'max'})) {
					$ok = 1;
				}
			}
			
		} elsif ($type eq 'bool') {
			$ok = 1;
		}
		unless($ok) {
			throw EBox::Exceptions::External(
		  	  $opt . " " . __('is not a valid option'));

		}

	}
}

sub _driverOptionsFile($$)
{
	my $self = shift;
	my $id = shift;
	
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}

	my $options = $self->_cacheDrvOptions($id);
	return $options if $options;
	
	
	my $printer = $self->model($id);
	my $manufacturer = $self->manufacturer($id);
	my $printerid = $self->_printerFromManuModel($manufacturer, $printer);
	$printerid or return {};
	
	my $db = new Foomatic::DB;
	my $dat = $db->getdat($self->driver($id), $printerid);
	for my $key (keys %{$dat->{args_byname}}){
		$options->{$key} = {
			'text' => $dat->{args_byname}->{$key}->{comment},
			'value' => $dat->{args_byname}->{$key}->{default} };
		
		# Values could be int, float, enum, or bool
		# int and float have valid range
		my $type = $dat->{args_byname}->{$key}->{'type'};
		$options->{$key}->{'type'} = $type;
		if (($type eq 'int') or ($type eq 'float')) { 
			$options->{$key}->{'min'} =  
					$dat->{args_byname}->{$key}->{'min'};
			$options->{$key}->{'max'} =  
				 	 $dat->{args_byname}->{$key}->{'max'};
		} 
		
		my @values;
		for my $vals (@{$dat->{args_byname}->{$key}->{vals}}) {
			my $text = $vals->{comment};
			push (@values, {$vals->{value} => $vals->{comment}});
        	}
        	$options->{$key}->{options} = \@values;
	}
	
	$self->_saveCacheDrvOptions($id, $options);
	return $options;
}

sub _setDriverOptionsToFile($$)
{
	my $self = shift;
	my $id  = shift;
	
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}
	unless ($self->_printerConfigured($id)) {
		throw EBox::Exceptions::External(__('Printer not configured'));
	}
	
	my $printer = $self->model($id);
	my $manufacturer = $self->manufacturer($id);
	my $driver = $self->driver($id);
	my $defaults = $self->driverOptions($id);

	my $printerid = $self->_printerFromManuModel($manufacturer, $printer);
	$printerid or return {};
	
	my $ppd = PPDBASEPATH . $manufacturer . "/$printerid-$driver.ppd.gz";
	command("/bin/cp $ppd " . EBox::Config::tmp);
	my $db = new Foomatic::DB;
	my $dat = $db->getdat($driver, $printerid);

	for my $arg (keys %{$defaults}){
		if (defined($db->{dat}->{args_byname}->{$arg})){
			$db->{dat}->{args_byname}->{$arg}->{default} = 
						     $defaults->{$arg}->{value};
		} else {
			throw EBox::Exceptions::External(
			 __x("Parameter '{name}' does not exist", name => $arg));
		}
	}

	my $tmpfile = EBox::Config::tmp . "$printerid-$driver.ppd";
	$db->ppdsetdefaults($tmpfile . ".gz");
	command("/bin/gunzip -f $tmpfile.gz"); 
	my $info = $self->_printerInfo($id);
	root("/bin/mv $tmpfile " .  CUPSPPD . $info->{name} . ".ppd");
}

sub printerJobs # (printerid, completed)
{
	my $self = shift;
	my $id = shift;
	my $completed = shift;

	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}
	unless ($self->_printerConfigured($id)) {
		throw EBox::Exceptions::External(__('Printer not configured'));
	}

	my $info = $self->_printerInfo($id);
	my @jobs =  cupsGetJobs($info->{'name'}, 0, $completed);
	if (@jobs and ($jobs[0])) {
		return \@jobs;

	} else {
		return [];
	}
}

sub cancelJob # (printername, jobid)
{
	my $self = shift;
	my $printer = shift;
	my $jobid = shift;
	
	unless ($self->_printerNameExists($printer)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$printer");
	}
	
	cupsCancelJob($printer, $jobid);
}

sub usbDevices 
{
	my $self;

	my @devices;

	for my $dev (0..9) {
		push (@devices, "usb$dev");
	}

	return \@devices;
}

sub parallelDevices
{
	my $self;

	return ['lp0', 'lp1'];
}

# Method: networkPrinters
#
# 	Returns the printers configured as network printer
#
# Returns:
#
# 	array ref - holding the printer id's
# 	
sub networkPrinters
{
	my $self = shift;

	my @ids;
	foreach my $printer (@{$self->printers()}) {
		my $conf = $self->methodConf($printer->{id});				
		push (@ids, $printer->{id}) if ($conf->{method} eq 'network');
	}

	return \@ids;
}

sub _saveCacheDrvOptions # (id, options)
{
	my $self = shift;
	my $id = shift;
	my $options = shift;
	
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}

	my $file = EBox::Config::tmp . "printer-$id.st";

	store($options, $file);
}

sub _cacheDrvOptions # (id)
{
	my $self = shift;
	my $id = shift;
	
	unless ($self->_printerIdExists($id)) {
		throw EBox::Exceptions::DataNotFound('data'  => __('Printer'),
						     'value' => "$id");
	}
	
	my $file = EBox::Config::tmp . "printer-$id.st";
	unless ( -f "$file" ) {
		return undef;
	}

	my $options = retrieve($file);
	return $options;
}

sub _removeCacheDrvOptions # (id)
{
	my $self = shift;
	my $id = shift;
	
	my $file = EBox::Config::tmp . "printer-$id.st";
	unless ( -f "$file" ) {
		return undef;
	}
	
	command("/bin/rm $file");
}

# Impelment LogHelper interface

sub tableInfo {
	my $self = shift;
	my $titles = { 'job' => __('Job ID'),
		'printer' => __('Printer'),
		'owner' => __('Owner'),
		'timestamp' => __('Queued at'),
		'event' => __('Event')
	};
	my @order = ('timestamp', 'job', 'printer', 'owner', 'event');
	my $events = { 'queued' => __('Queued'), 'canceled' => __('Canceled') };

	return {
		'name' => __('Printers'),
		'index' => 'printers',
		'titles' => $titles,
		'order' => \@order,
		'tablename' => 'jobs',
		'timecol' => 'timestamp',
                'filter' => ['printer', 'owner'],
                'events' => $events,
                'eventcol' => 'event'
								
	};
}
sub logHelper
{
	my $self = shift;
	
	if ($self->service()) {
		return (new EBox::PrinterLogHelper);
	} else {
		return undef;
	}
}

# Helper functions
sub _checkPrinterName ($)
{
        my $name = shift;
        (length($name) <= MAXPRINTERLENGHT) or return undef;
        (length($name) > 0) or return undef;
	($name =~ /^[\w]+$/) or return undef;
        return 1;
}

sub _checkSambaInstalled 
{
	my $samba = EBox::Global->modInstance('samba');
	return  $samba ? 1 : undef;
}

1;
