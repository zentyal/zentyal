#!/usr/bin/perl

#	Migration between gconf data version 0 to 1
#
#	In version 1, a new model has been created to store firewall rules and it
#	lives in another module called services. In previous versions
#	servies were stored in firewall.
#	
#	This migration script tries to populate the services model with the
#	stored services in firewall
#
package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Data::Dumper;
use EBox::Model::ModelManager;
use Socket;
use Error qw(:try);




sub _setDefaultInternalServices
{
    my ($self) = @_;

    my $fw = $self->{gconfmodule};

    # the setInternalService doesn'tadd anything if there is already a rule so
    # this safe with previous version that used the onInstall method
    $fw->setInternalService('eBox administration', 'accept');
    $fw->setInternalService('ssh', 'accept');
    
    $fw->saveConfigRecursive();
}

sub runGConf
{
    my ($self) = @_;

    $self->_setDefaultInternalServices();
}

EBox::init();

my $fwMod = EBox::Global->modInstance('firewall');
my $migration = new EBox::Migration( 
				    'gconfmodule' => $fwMod,
				    'version' => 2,
				   );

$migration->execute();
