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

# Migration between gconf data version 1 to 2
#
# If there is already a bundle downloaded changed its version number this is
# needed because remote service version check is added and otherwise ti could be
# skipped
#

package EBox::Migration;

use base 'EBox::Migration::Base';

use strict;
use warnings;

use EBox;
use EBox::Global;

sub runGConf
{
    my ($self) = @_;

    my $rs = $self->{gconfmodule};
    if (not $rs->eBoxSubscribed()) {
        # not subscibed nothing to do..
        return;
    }

    my $bundleVersion = $rs->bundleVersion();
    if ($bundleVersion == 0) {
        # no bundle, niothing to do..
        return;
    }

    my $adjustedBundleVersion = $bundleVersion -1;
    my $confFiles = $rs->subscriptionDir . '/*.conf';
    my $replaceCmd = "s/version\\s*=\\s*$bundleVersion/version=$adjustedBundleVersion/";
    my $sedCmd = "sed -i -e'$replaceCmd' $confFiles";
    system $sedCmd;
    if ($? != 0) {
        EBox::error("Error running $sedCmd in zentyal-remoteservices migration. Set manually bundle version to $adjustedBundleVersion");
    }
}

EBox::init();

my $rsMod = EBox::Global->modInstance('remoteservices');
my $migration = __PACKAGE__->new(gconfmodule => $rsMod,
                                 version     => 2);

$migration->execute();
