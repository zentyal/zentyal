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

#  Migration between gconf data version 0 and 1
#
#   db changes: source field is wider to accomadate longer source names


package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Migration::Helpers;


sub runGConf
{
    my ($self) = @_;

    EBox::Migration::Helpers::renameTable('ids', 'ids_event');
    

    my $query;
    # consolidation has changed so we must rerun, we do deleting the
    # accummulation report data
    $query = 'delete from ids_report';
    EBox::Migration::Helpers::runQuery($query);

    $query = q{delete from report_consolidation where report_table='ids_report'};
    EBox::Migration::Helpers::runQuery($query);

    # add and remove columns
    $query =    'ALTER TABLE ids_report ' .
                'DROP COLUMN alerts,' .
                'ADD COLUMN priority1 BIGINT DEFAULT 0,' .  
                'ADD COLUMN priority2 BIGINT DEFAULT 0,' .  
                'ADD COLUMN priority3 BIGINT DEFAULT 0,' .  
                'ADD COLUMN priority4 BIGINT DEFAULT 0,' .  
                'ADD COLUMN priority5 BIGINT DEFAULT 0'; 
                    ;
    EBox::Migration::Helpers::runQuery($query);

}


EBox::init();

my $mod = EBox::Global->modInstance('ids');
my $migration =  __PACKAGE__->new(
    'gconfmodule' => $mod,
    'version' => 1
);
$migration->execute();
