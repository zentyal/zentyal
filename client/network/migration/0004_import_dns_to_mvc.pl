#!/usr/bin/perl

#	Migration between gconf data version 2 to 3
#
#	In version 3, static routes are now handled by MVC. So we must
#	import old gconf keys to the new scheme.
#
package EBox::Migration;

use strict;
use warnings;

use base 'EBox::MigrationBase';

# eBox uses
use EBox;
use EBox::Global;

# Constants:

# Old keys
use constant NS1_OLD_KEY            => 'nameserver1';
use constant NS2_OLD_KEY            => 'nameserver2';
# Model names
use constant DNSRESOLVER_MODEL_NAME => 'DNSResolver';
# New keys
use constant RESOLVER_KEY           => 'nameserver';

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

    # Import the primary and secondary nameserver resolver from old
    # fashioned table to the new one MVC  based
    my $network = $self->{gconfmodule};

    my $nameserver1 = $network->get_string(NS1_OLD_KEY);
    my $nameserver2 = $network->get_string(NS2_OLD_KEY);

    my $newDNSResolverKey = DNSRESOLVER_MODEL_NAME . '/keys';
    # Set the new keys and unset the old ones
    if ( defined($nameserver1) and $nameserver1) {
        EBox::info("Migrating primary name server resolver $nameserver1 to DNSResolver model");
        $network->set_string( "$newDNSResolverKey/dnsr1/" . RESOLVER_KEY,
                              $nameserver1);
        # Set the order
        $network->set_list( DNSRESOLVER_MODEL_NAME . '/order', 'string',
                            [ 'dnsr1' ]);
        $network->unset(NS1_OLD_KEY);
    }
    if ( defined($nameserver2) and $nameserver2) {
        EBox::info("Migrating secondary name server resolver $nameserver2 to DNSResolver model");
        $network->set_string( "$newDNSResolverKey/dnsr2/" . RESOLVER_KEY,
                              $nameserver2);
        $network->set_list( DNSRESOLVER_MODEL_NAME . '/order', 'string',
                            [ 'dnsr1', 'dnsr2' ]);
        $network->unset(NS2_OLD_KEY);
    }

}

EBox::init();
my $network = EBox::Global->modInstance('network');
my $migration = new EBox::Migration(
    'gconfmodule' => $network,
    'version' => 4,
);
$migration->execute();
