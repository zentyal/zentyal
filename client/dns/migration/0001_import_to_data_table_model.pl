#!/usr/bin/perl

#	Migration between gconf data version 0 to 1
#
#	In version 1, a new model has been created to store objects.
#	This migration script tries to populate the model with the
#	stored objects using the former data model which used gconf directly.
#
package EBox::Migration;
use strict;
use warnings;
use EBox;
use EBox::Global;
use EBox::NetWrappers qw(:all);
use EBox::Validate qw(:all);

use base 'EBox::MigrationBase';

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
    my $dns = $self->{'gconfmodule'};
    
    my @dirs_to_delete;
    foreach my $domain (@{$self->_getGConfData()}) {
	push(@dirs_to_delete, $domain->{'id'});
        $dns->addDomain($domain);
	
    }

    foreach my $dir (@dirs_to_delete)
    {
        $dns->delete_dir($dir);
    }
}

sub _getGConfData
{
	my ($self) = @_;
	my $gconf = $self->{'gconfmodule'};

	my @domains;
	foreach my $domainData (@{$self->_domainDataArray()})
	{
		my $domain;
		$domain->{'domain_name'} = $domainData->{'name'};
		$domain->{'id'} = $domainData->{'id'};
		
		my @members;
		foreach my $member (@{$domainData->{'member'}})
		{
			my $hostnames;
			
			$hostnames->{'hostname'} = $member->{'name'};
			$hostnames->{'ip'} = $member->{'ip'};
			
			my @aliases;
			foreach my $alias (@{$member->{'aliases'}})
			{
				push(@aliases, $alias->{'name'});
			}
			
			$hostnames->{'aliases'} = \@aliases;
			push (@members, $hostnames);
		}
		
		$domain->{'hostnames'} = \@members;

		push(@domains, $domain);
	}

	return \@domains;
}

sub _domainDataArray
{
	my ($self) = @_;
	my $gconf = $self->{'gconfmodule'};

	my @array = ();
	my @domainData = @{$gconf->all_dirs_base("")};
	foreach my $domData (@domainData)
	{
		my $hash = $gconf->hash_from_dir($domData);
		
		$hash->{id} = $domData;
		$hash->{member} = $gconf->array_from_dir($domData);
		
		my $parentdir = $domData;
		foreach my $alias (@{$hash->{member}})
		{
			my $hash2 = $gconf->array_from_dir($parentdir . "/". $alias->{_dir});
			$alias->{'aliases'} = $hash2;
		}

		push(@array, $hash);
	}

	return \@array;
}

EBox::init();
my $dns = EBox::Global->modInstance('dns');
my $migration = new EBox::Migration( 
    'gconfmodule' => $dns,
    'version' => 1
);
$migration->execute();
