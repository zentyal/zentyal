#!/usr/bin/perl

# Copyright (C) 2008-2010 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

#  Migration between gconf data version 0 and 1
#
#   gconf changes: now service is explitted in intrnalService and userService
#   files changes: now log files names have the name of the daemon instead of
#   the iface daemons change: now start and stop of daemons have a new method
#   depending in pid files
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::Migration::Base';

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
    foreach my $id (@{$objectPolicies->ids()}) {
        my $row = $objectPolicies->row($id);
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
        $usersMod->enableActions();
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
