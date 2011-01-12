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

#	Migration between gconf data version 2 and 3
#
#
#   This migration script creates the plpgsql language
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Global;

sub runGConf
{
    my ($self) = @_;

    my $cmd = qq{echo "CREATE LANGUAGE plpgsql" | sudo su postgres -c 'psql eboxlogs' > /dev/null 2>&1};
    system $cmd;
}

EBox::init();

my $mod = EBox::Global->modInstance('logs');
my $migration = new EBox::Migration(
				    'gconfmodule' => $mod,
				    'version' => 3,
				   );

$migration->execute();
