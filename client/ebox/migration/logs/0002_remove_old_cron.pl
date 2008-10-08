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
#   gconf changes: we must remove the values of the CongigureLogTableModel to
#  allow his regenration with the new column 'lifeTime' in the next call of the
#  rows method

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

use constant OLD_CRON => '/etc/cron.hourly/99purgeEBoxLogs';


sub runGConf
{
  my ($self) = @_;

  EBox::Sudo::root('rm -f ' . OLD_CRON);
}

EBox::init();
my $logs = EBox::Global->modInstance('logs');
my $migration = new EBox::Migration( 
                                     'gconfmodule' => $logs,
                                     'version' => 2
                                    );
$migration->execute();

1;
