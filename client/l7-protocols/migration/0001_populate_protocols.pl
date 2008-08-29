#!/usr/bin/perl

#	Migration between gconf data version 0 to 1
#
#   Populate protocols from /etc/l7filter
#
package EBox::Migration;
use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::NetWrappers qw(:all);
use EBox::Validate qw(:all);
use EBox::Gettext;
use Error qw(:try);

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
    
    $self->{'gconfmodule'}->populateProtocols();
    
}

EBox::init();
my $l7Module = EBox::Global->modInstance('l7-protocols');
my $migration = new EBox::Migration( 
    'gconfmodule' => $l7Module,
    'version' => 1
);

$migration->execute();
