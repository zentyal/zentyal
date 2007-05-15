#!/usr/bin/perl

#	Migration between gconf data version 0 to 1
#
#	In version 1, a new table to store gateways has been added.
#	This migration script tries to add the former default router
#	to this new table
#
package EBox::Migration;
use strict;
use warnings;
use EBox;
use EBox::Global;
use EBox::NetWrappers qw(:all);
use EBox::Validate qw(:all);

use base 'EBox::MigrationBase';

use constant DEFAULT_IFACE => 'eth0';
use constant DEFAULT_UPLOAD => '1024';
use constant DEFAULT_DOWNLOAD => '1024';
use constant DEFAULT_NAME => 'default';
use constant BASE_KEY => 'gatewaytable/keys/todo1111';

sub new 
{
	my $class = shift;
	my %parms = @_;

	my $self = $class->SUPER::new(@_);
	bless($self, $class);

	return $self;
}

# Method: runGConf
#
#
sub runGConf
{
	my $self = shift;
	my $network = $self->{'gconfmodule'};

	my $gw = $network->get_string('gateway');
	return unless ($gw);
	
	my $iface = $self->_getIfaceForGw($gw);
	unless (defined($iface)) {
		$iface = DEFAULT_IFACE;
	}
	
	$network->set_string(BASE_KEY . '/ip', $gw);
	$network->set_string(BASE_KEY . '/interface', $gw);
	$network->set_bool(BASE_KEY . '/default', 1);
	$network->set_int(BASE_KEY . '/upload', DEFAULT_UPLOAD);
	$network->set_int(BASE_KEY . '/download', DEFAULT_DOWNLOAD);

}

sub _getIfaceForGw
{
	my $self = shift;
	my $gw   = shift;
	
	my $network = $self->{'gconfmodule'};
	my $cidr_gw = "$gw/32";
	foreach my $iface (@{$network->allIfaces()}) {
		my $host = $network->ifaceAddress($iface);
		my $mask = $network->ifaceNetmask($iface);
		my $meth = $network->ifaceMethod($iface);
		checkIPNetmask($gw, $mask) or next;
		($meth eq 'static') or next;
		(defined($host) and defined($mask)) or next;
		if (isIPInNetwork($host, $mask, $cidr_gw)) {
			return $iface;
		}
	}

	return undef;
}

EBox::init();
my $network = EBox::Global->modInstance('network');
my $migration = new EBox::Migration( 
				     'gconfmodule' => $network,
				     'version' => 1
				    );
$migration->execute();				     
