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

#  Migration between gconf data version 0 and 1
#
#  In version 0, these attributes are stored per log watcher:
#     * eventWatcher - String
#     * enabled      - Boolean
#
#  In version 1, the 'configuration' field is added:
#     * configuration_selected - String
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
use constant DEFAULT_CONFIGURATION    => 'configuration_none';
use constant CONFIGURATION_FIELD_NAME => 'configuration_selected';

sub runGConf
{
  my ($self) = @_;

  my $eventsMod = $self->{gconfmodule};

  my $confEventTableKey = 'configureEventTable/keys';

  # Return if it does NOT exist
  return unless $eventsMod->dir_exists($confEventTableKey);

  foreach my $confDir (@{$eventsMod->all_dirs_base($confEventTableKey)}) {
    my $confKey = "$confEventTableKey/$confDir/" . CONFIGURATION_FIELD_NAME;
    unless ( $eventsMod->get_string($confKey) ) {
        $eventsMod->set_string($confKey, DEFAULT_CONFIGURATION);
    }
  }
}

EBox::init();
my $events = EBox::Global->modInstance('events');
my $migration = new EBox::Migration(
				     'gconfmodule' => $events,
				     'version' => 1
				    );
$migration->execute();

1;
