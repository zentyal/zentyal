#!/usr/bin/perl

#  Migration between gconf data version 0 and 1
#
#   gconf changes: now service is explitted in intrnalService and userService
#   files changes: now log files names have the name of the daemon instead of
#   the iface daemons change: now start and stop of daemons have a new method
#   depending in pid files
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Config;

sub runGConf
{
  my ($self) = @_;

  $self->_migrateObjectPolicies();
  $self->_enableUsersAndGroups();

}



sub _migrateObjectPolicies
{
    my ($self) = @_;

    my $squid = EBox::Global->modInstance('squid');
    my $objectPolicies = $squid->model('ObjectPolicy');
    my @rows = @{  $objectPolicies->rows() };
    
    foreach my $row (@rows) {
        my $timePeriod = $row->elementByName('timePeriod');
        $timePeriod->setValue('MTWHFAS');
        $row->store();
    }


}


sub _enableUsersAndGroups
{
    my ($self) = @_;
    my $squid = EBox::Global->modInstance('squid');
    if (not $squid->configured() ) {
        return;
    }

    my $usersMod = EBox::Global->modInstance('users');


    unless ( $usersMod->configured() ) {
        $usersMod->setConfigured(1);
        $usersMod->enabledActions();
        $usersMod->save();
    }
    unless ( $usersMod->isEnabled() ) {
        $usersMod->enableService(1);
        $usersMod->save();
    }
}


EBox::init();
my $squid = EBox::Global->modInstance('squid');
my $migration = new EBox::Migration( 
                                     'gconfmodule' => $squid,
                                     'version' => 2,
                                    );
$migration->execute();                               


1;
