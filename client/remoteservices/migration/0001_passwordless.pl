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

# Migration between gconf data version 0 to 1
#
# In version 1, the access setting from CC is always passwordless
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

    $rs->set_bool('AccessSettings/passwordless', 1);
    $rs->set_bool('AccessSettings/readOnly', 0);
    my $version = $rs->get_int('AccessSettings/version');
    $version = 0 unless defined($version);
    $rs->set_int('AccessSettings/version', $version+1);

}

EBox::init();

my $rsMod = EBox::Global->modInstance('remoteservices');
my $migration = __PACKAGE__->new(gconfmodule => $rsMod,
                                 version     => 1);

$migration->execute();
