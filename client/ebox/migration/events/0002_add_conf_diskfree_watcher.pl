#!/usr/bin/perl
# Copyright (C) 2007 Warp Networks S.L.
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

#  Migration between gconf data version 1 and 2
#
#  In version 1, the configuration selected for the DiskFreeSpace
#  Watcher is none. However, the next version (2) has a configuration
#  model which must be marked on GConf database.
#

use strict;
use warnings;

package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Config;
use EBox::Sudo;

# Constants
use constant WATCHER_FIELD_NAME          => 'eventWatcher';
use constant DISKFREESPACE_EVENT_WATCHER => 'EBox::Event::Watcher::DiskFreeSpace';
use constant CONFIGURATION_FIELD_NAME    => 'configuration_selected';
use constant CONFIGURATION_VALUE         => 'configuration_model';

sub runGConf
{
  my ($self) = @_;

  my $eventsMod = $self->{gconfmodule};

  my $confEventTableKey = 'configureEventTable/keys';

  # Return if it does NOT exist
  return unless $eventsMod->dir_exists($confEventTableKey);

  foreach my $confSubDir (@{$eventsMod->all_dirs_base($confEventTableKey)}) {
      my $confDir = "$confEventTableKey/$confSubDir/";

      my $eventWatcher = $eventsMod->get_string($confDir . WATCHER_FIELD_NAME);
      next unless ( $eventWatcher eq DISKFREESPACE_EVENT_WATCHER );

      $eventsMod->set_string( $confDir . CONFIGURATION_FIELD_NAME,
                              CONFIGURATION_VALUE);
      last;
  }
}

EBox::init();
my $events = EBox::Global->modInstance('events');
my $migration = new EBox::Migration(
				     'gconfmodule' => $events,
				     'version' => 2
				    );
$migration->execute();

1;
