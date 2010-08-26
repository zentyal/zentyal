#!/usr/bin/perl
#   Migration between gconf data version 1 to 2
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

#
#   This migration script removes the old /etc/cron.daily/ebox-software file if
#   exists

package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use Error qw(:try);


sub runGConf
{
    my ($self) = @_;

    EBox::Sudo::root("rm -f /etc/cron.daily/ebox-software");
}

EBox::init();

my $softwareMod = EBox::Global->modInstance('software');
my $migration =  __PACKAGE__->new(
    'gconfmodule' => $softwareMod,
    'version' => 2
);
$migration->execute();
