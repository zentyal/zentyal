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

# Move old sieve dir /var/sieve-scripts to new location
#
package EBox::Migration;
use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Sudo;

sub runGConf
{
    my ($self) = @_;

    my $oldDir = '/var/sieve-scripts';
    my $newDir = '/var/vmail/sieve';

    my $existsOld = EBox::Sudo::fileTest('-d', $oldDir);
    if (not $existsOld) {
        # no old directoy, nothing to migrate
        return;
    }

    EBox::Sudo::root("mv -T $oldDir $newDir");
    EBox::Sudo::root("rm -rf $oldDir");
}




EBox::init();

my $mailMod = EBox::Global->modInstance('mail');
my $migration =  __PACKAGE__->new(
        'gconfmodule' => $mailMod,
        'version' => 11
        );
$migration->execute();
