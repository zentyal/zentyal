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
    my $objects = $self->{'gconfmodule'};

    foreach my $object (@{$self->_objectsArray()}) {
        next unless ($object->{'name'} and $object->{'description'});
        my $id = $object->{'name'};
        my $name = $object->{'description'};
        my @members;
        foreach my $member (@{$object->{'member'}}) {
            next unless (defined($member->{'ip'}));
            my $mac = $member->{'mac'};
            unless (defined($mac) and length ($mac) > 0) {
                $mac = undef;
            }

            push (@members,
                {
                    'name' =>   $member->{'nname'},
                    'ipaddr_ip' => $member->{'ip'},
                    'ipaddr_mask' => $member->{'mask'},
                    'macaddr' => $mac
                });
        }
        EBox::info("migrating object: $name with id $id");

        $objects->addObject(
            'id' => $id,
            'name' => $name,
            'members' => \@members);

        $objects->delete_dir($id);
    }
}

sub _objectsArray
{
    my ($self) = @_;
    my $gconf = $self->{'gconfmodule'};

    my @array = ();
    my @objs = @{$gconf->all_dirs_base("")};
    foreach my $id (@objs) {
        EBox::info("model 0 object $_");
        my $hash = $gconf->hash_from_dir($id);
        $hash->{name} = $id;
        $hash->{member} = $gconf->array_from_dir($id);
        push(@array, $hash);
    }
    return \@array;
}

EBox::init();
my $objects = EBox::Global->modInstance('objects');
my $migration = new EBox::Migration( 
    'gconfmodule' => $objects,
    'version' => 1
);
$migration->execute();
