#!/usr/bin/perl

# Copyright (C) 2010 eBox Technologies S.L.
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

#  Migration between  data version 1 and 2
#
#  Remove no longer used cron script for fresclam but the freshclam in
#  daemon mode
#
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Sudo;

# Constants
use constant CRON_SCRIPT => '/etc/cron.hourly/freshclam';

sub runGConf
{
    my ($self) = @_;

    if ( -f CRON_SCRIPT ) {
        EBox::Sudo::root('rm -f ' . CRON_SCRIPT);
    }

}


EBox::init();
my $antivirus = EBox::Global->modInstance('antivirus');
my $migration = new EBox::Migration(
    'gconfmodule' => $antivirus,
    'version' => 2
   );
$migration->execute();

1;
