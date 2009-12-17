#!/usr/bin/perl

#
# This is a migration script to import multigateway rules into
# the new service based model
#

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Socket;

sub _migrateToServices
{
    my ($self) = @_;

    my $network = EBox::Global->modInstance('network');
    my $services = EBox::Global->modInstance('services');

    my %serviceIdByDescription = %{ $self->_serviceIdByDescription()  };

    my @srvs = @{$network->all_dirs_base("multigwrulestable/keys")};
    foreach my $row (@srvs) {
        my $srv = $network->hash_from_dir("multigwrulestable/keys/$row");


        my $protocol = $srv->{'protocol'};
        unless (defined($protocol)) {
            $protocol = 'any';
        }
        my $srcPort = $srv->{'source_port'};
        unless (defined($srcPort)) {
            $srcPort = 'any';
        }
        my $dstPort = $srv->{'destination_port'};
        unless (defined($dstPort)) {
            $dstPort = 'any';
        }

        my $enabled;
        if (exists $srv->{'enabled'}) {
            $enabled = $srv->{'enabled'};
        } else {
            $enabled = 1;
        }


        my $id;
        my $description  =  "src: $srcPort dst: $dstPort proto: $protocol";

        if (exists $serviceIdByDescription{$description}) {
            $id = $serviceIdByDescription{$description};
        }
        else {
            # make a custom service
            my $name;
            if (($dstPort ne 'any') and ($protocol ne 'any') and ($srcPort eq 'any')) {
                $name  = getservbyport($dstPort, $protocol);
            }

            if (not defined($name)) {
                $name = $description;
            }
            elsif ($services->serviceExists('name' => $name)) {
                $name = $description;
            }
            $id = $services->addService(
                'name' => $name,
                'description' => 'Service generated from migration scripts',
                'protocol' => $protocol,
                'sourcePort' => $srcPort,
                'destinationPort' => $dstPort,
                'internal' => 0
               );

        }

        $network->set_string("multigwrulestable/keys/$row/service", $id);
        $network->unset("multigwrulestable/keys/$row/protocol");
        $network->unset("multigwrulestable/keys/$row/source_port");
        $network->unset("multigwrulestable/keys/$row/destination_port");
        $network->set_bool("multigwrulestable/keys/$row/enabled", $enabled);
    }
}


sub _serviceIdByDescription
{
    my ($self) = @_;

    my %services;

    my $services = EBox::Global->modInstance('services');


    my @servicesSpec = @{ $services->serviceNames()};
    foreach my $spec (@servicesSpec) {
        my $name = $spec->{name};
        my $id   = $spec->{id};
        my @conf =  @{  $services->serviceConfiguration($id) };
        if (@conf != 1) {
            # for migration purposes we can only migrate to services with a
            # single port or group of ports
            next;
        }

        my $conf = shift @conf;
        my $protocol = $conf->{protocol};
        my $srcPort = $conf->{source};
        defined $srcPort or $srcPort  = 'any';
        my $dstPort = $conf->{destination};
        defined $dstPort or $dstPort = 'any';

        # port range services are useless for migration
        if ($srcPort =~ m/:/) {
            next;
        } elsif ($dstPort =~ m/:/) {
            next;
        }

        my $description  =  "src: $srcPort dst: $dstPort proto: $protocol";
        $services{$description} = $id;
    }

    return \%services;
}


sub _migrateTrafficBalancing
{
    my ($self) = @_;

    my $network = $self->{gconfmodule};
    my $oldKey = 'balanceTraffic';
    if ($network->get_bool($oldKey)) {
        $network->unset($oldKey);

        my $newKey = 'MultiGwRulesOptions/balanceTraffic';
        $network->set_bool($newKey, 1);
    }

}

sub runGConf
{
    my ($self) = @_;

    $self->_migrateToServices();
    $self->_migrateTrafficBalancing();

    my $services = EBox::Global->modInstance('services');
    $services->saveConfig();
}

EBox::init();

my $network = EBox::Global->modInstance('network');
my $migration = new EBox::Migration(
    'gconfmodule' => $network,
    'version' => 5,
);
$migration->execute();
