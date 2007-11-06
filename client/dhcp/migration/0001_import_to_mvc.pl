#!/usr/bin/perl

#	Migration between gconf data version 0 to 1
#
#	In version 1, a new model has been created to store ranges,
#	fixed addresses and options from every static interface. This
#	import the old values to the new data model and set a default
#	value for every new configuration element such as leased
#	times.
#
package EBox::Migration;

use strict;
use warnings;

use base 'EBox::MigrationBase';

# eBox uses
use EBox;
use EBox::Global;

use Perl6::Junction qw(any);

# Constants:
use constant DEFAULT_DISABLED => 0;
use constant OPTIONS_MODEL_NAME => 'Options';
use constant FIXED_MODEL_NAME   => 'FixedAddressTable';
use constant RANGES_MODEL_NAME  => 'RangeTable';
use constant ENABLED_MODEL_NAME => 'EnabledForm';

# Group: Public methods

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
# Overrides:
#
#      <EBox::MigrationBase::runGConf>
#
sub runGConf
{
    my ($self) = @_;

    $self->_importService();
    $self->_importOptions();
    $self->_importRanges();
    $self->_importFixedAddresses();

}

# Group: Private methods

# Import service enabled from old version
sub _importService
{
    my ($self) = @_;

    my $dhcp = $self->{gconfmodule};
    my ($active, $enabled);

    if ( any(@{$dhcp->all_entries_base('')}) eq 'active' ) {
        $active = $dhcp->get_bool('active');
    } else {
        $active = undef;
    }

    if ( defined ( $active )) {
        $dhcp->set_bool(ENABLED_MODEL_NAME . '/enabled', $active);
    } else {
        $dhcp->set_bool(ENABLED_MODEL_NAME . '/enabled', DEFAULT_DISABLED);
    }

    $dhcp->unset('active');

}

# Import the options from the old conf
sub _importOptions
{

    my ($self) = @_;
    my $dhcp = $self->{gconfmodule};

    my $ifaces = $dhcp->all_dirs_base('');
    foreach my $iface (@{$ifaces}) {
        next unless ( grep { $_ eq 'gateway' } @{$dhcp->all_entries_base("$iface")});
        my $defaultGw = $dhcp->get_string("$iface/gateway");
        my $searchDomain = $dhcp->get_string("$iface/search");
        my $primaryNS = $dhcp->get_string("$iface/nameserver1");
        my $secondaryNS = $dhcp->get_string("$iface/nameserver2");
        # Set the values as it is saved by the model
        if ( $defaultGw eq '' ) {
            $dhcp->set_string(OPTIONS_MODEL_NAME . "/$iface/default_gateway_selected",
                              'none');
        } else {
            $dhcp->set_string(OPTIONS_MODEL_NAME . "/$iface/default_gateway_selected",
                              'ip');
            $dhcp->set_string(OPTIONS_MODEL_NAME . "/$iface/ip", $defaultGw);
        }
        if ( $searchDomain eq '' ) {
            $dhcp->set_string(OPTIONS_MODEL_NAME . "/$iface/search_domain_selected",
                              'none');
        } else {
            $dhcp->set_string(OPTIONS_MODEL_NAME . "/$iface/search_domain_selected",
                              'custom');
            $dhcp->set_string(OPTIONS_MODEL_NAME . "/$iface/custom",
                              $searchDomain);
        }
        if ( $primaryNS eq '' ) {
            $dhcp->set_string(OPTIONS_MODEL_NAME . "/$iface/primary_ns_selected",
                              'none');
        } else {
            $dhcp->set_string(OPTIONS_MODEL_NAME . "/$iface/primary_ns_selected",
                              'custom_ns');
            $dhcp->set_string(OPTIONS_MODEL_NAME . "/$iface/custom_ns",
                              $primaryNS);
        }
        if ( $secondaryNS ne '' ) {
            $dhcp->set_string(OPTIONS_MODEL_NAME . "/$iface/secondary_ns",
                              $secondaryNS);
        }
        # Unset current values
        $dhcp->unset("$iface/gateway");
        $dhcp->unset("$iface/search");
        $dhcp->unset("$iface/nameserver1");
        $dhcp->unset("$iface/nameserver2");
    }

}

# Import the ranges from old fashioned table to the new one
sub _importRanges
{
    my ($self) = @_;
    my $dhcp = $self->{gconfmodule};

    my $ifaces = $dhcp->all_dirs_base('');
    foreach my $iface (@{$ifaces}) {
        next unless ( $dhcp->dir_exists("$iface/ranges") );
        my $rangesDir = $dhcp->array_from_dir("$iface/ranges");
        foreach my $range (@{$rangesDir}) {
            my $rangeId = $range->{_dir};
            my $from = $range->{from};
            my $to   = $range->{to};
            my $name = $range->{name};
            my $newRangeKey = RANGES_MODEL_NAME . "/$iface/keys/$rangeId";
            # Set the new keys
            $dhcp->set_string( "$newRangeKey/name", $name);
            $dhcp->set_string( "$newRangeKey/from", $from);
            $dhcp->set_string( "$newRangeKey/to"  , $to);
            # Unset old ones
            $dhcp->unset("$iface/ranges/$rangeId");
        }
    }
}

# Import the fixed address assignments from old fashioned table to the
# new one
sub _importFixedAddresses
{
    my ($self) = @_;
    my $dhcp = $self->{gconfmodule};

    my $ifaces = $dhcp->all_dirs_base('');
    foreach my $iface (@{$ifaces}) {
        next unless ( $dhcp->dir_exists("$iface/fixed") );
        my $fixedDir = $dhcp->array_from_dir("$iface/fixed");
        foreach my $fixedMap (@{$fixedDir}) {
            my $fixedId = $fixedMap->{_dir};
            my $name = $fixedMap->{name};
            my $mac = $fixedMap->{mac};
            my $ip   = $fixedMap->{ip};
            my $newFixedKey = FIXED_MODEL_NAME . "/$iface/keys/$fixedId";
            # Set the new keys
            $dhcp->set_string( "$newFixedKey/name", $name);
            $dhcp->set_string( "$newFixedKey/mac" , $mac);
            $dhcp->set_string( "$newFixedKey/ip"  , $ip);
            # Unset old ones
            $dhcp->unset("$iface/fixed/$fixedId");
        }
    }
}

EBox::init();
my $dhcp = EBox::Global->modInstance('dhcp');
my $migration = new EBox::Migration(
    'gconfmodule' => $dhcp,
    'version' => 1
);
$migration->execute();
