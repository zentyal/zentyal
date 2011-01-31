#!/usr/bin/perl

# Copyright (C) 2011 eBox Technologies S.L.
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

#   Fix event column in mail_message_report to match the definition
#   that has in mail_message table

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Global;
use EBox::Migration::Helpers;

sub runGConf
{
    my $query = 'ALTER TABLE mail_message_report ALTER COLUMN event TYPE VARCHAR(255)';
    EBox::Migration::Helpers::runQuery($query);
}

EBox::init();

my $mod = EBox::Global->modInstance('mail');
my $migration = new EBox::Migration(
				    'gconfmodule' => $mod,
				    'version' => 13,
				   );

$migration->execute();
