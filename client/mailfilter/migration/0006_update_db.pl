#!/usr/bin/perl
#
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

#       Migration between gconf data version 5 to 6
#
#
#   This migration script changes the names of some fields and tables
#
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
    # smtp mailfilter
    EBox::Migration::Helpers::dropIndex('timestamp_i');
    EBox::Migration::Helpers::renameField('message_filter', 'date', 'timestamp');
    EBox::Migration::Helpers::renameTable('message_filter', 'mailfilter_smtp');
    EBox::Migration::Helpers::renameConsolidationTable('mailfilter_traffic', 'mailfilter_smtp_traffic');
    EBox::Migration::Helpers::createTimestampIndex('mailfilter_smtp');

    # pop mailfilter
    EBox::Migration::Helpers::dropIndex('timestamp_pop_timestamp_i');
    EBox::Migration::Helpers::renameField('pop_proxy_filter', 'date', 'timestamp');
    EBox::Migration::Helpers::renameTable('pop_proxy_filter', 'mailfilter_pop');
    EBox::Migration::Helpers::renameConsolidationTable('pop_proxy_filter_traffic', 'mailfilter_pop_traffic');
    EBox::Migration::Helpers::createTimestampIndex('mailfilter_pop');
}

EBox::init();

my $mod = EBox::Global->modInstance('mailfilter');
my $migration = new EBox::Migration(
                                    'gconfmodule' => $mod,
                                    'version' => 6,
                                   );

$migration->execute();
