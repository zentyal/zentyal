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

# This is a migration script to remove the NOT NULL condition for te column
# status in log table. NOT NULL conditon must be removed to avoid ilog insert fails 
#
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Config;
use EBox::Sudo;
use File::Slurp;



sub runGConf
{
    my ($self) = @_;

    my $cmdFile    = '/tmp/0007updateSqlTableXAZ';
    my $sqlCommand = 'ALTER TABLE mail_message ALTER COLUMN status DROP NOT NULL';
    File::Slurp::write_file($cmdFile, $sqlCommand);
    my $shellCommand = qq{su postgres -c'psql -f $cmdFile eboxlogs'};
    EBox::Sudo::root($shellCommand);
    EBox::Sudo::root("rm -rf $cmdFile");
}



EBox::init();

my $mailMod = EBox::Global->modInstance('mail');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mailMod,
        'version' => 8,
        );
$migration->execute();
