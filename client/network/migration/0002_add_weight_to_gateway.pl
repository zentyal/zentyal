#!/usr/bin/perl

#	Migration between gconf data version 1 to 2
#
#	In version 2, a new field to set gateway's weight has been added 
#	This migration scripts adds the weight field to existing gateways,
#	setting their value to 1
#
package EBox::Migration;
use strict;
use warnings;
use EBox;
use EBox::Global;
use EBox::NetWrappers qw(:all);
use EBox::Validate qw(:all);

use base 'EBox::MigrationBase';

use constant DEFAULT_WEIGHT => '1';
use constant DEFAULT_NAME => 'default';
use constant BASE_KEY => 'gatewaytable/keys';

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

	for my $gw (@{$network->array_from_dir(BASE_KEY)}) {
		my $key = BASE_KEY . "/$gw->{'_dir'}/weight";
		$network->set_int($key, 1);
	}

}

EBox::init();
my $network = EBox::Global->modInstance('network');
my $migration = new EBox::Migration( 
				     'gconfmodule' => $network,
				     'version' => 2 
				    );
$migration->execute();				     
